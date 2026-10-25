import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch


class VaultNotificationTests(unittest.TestCase):
    def setUp(self):
        fake=types.ModuleType('telegram_notify');fake.send_message=Mock()
        loader=importlib.machinery.SourceFileLoader('t7_notify_vault_test',str(Path(__file__).resolve().parents[1]/'scripts/t7-restic-notify'))
        self.app=importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name,loader))
        with patch.dict('sys.modules',{'telegram_notify':fake}):loader.exec_module(self.app)

    def test_each_send_resolves_current_vault_values_without_legacy_fallback(self):
        app=self.app
        with patch.dict(os.environ,{'T7_TELEGRAM_REFERENCE':'FEDORA_TELEGRAM_ENV','BWS_ACCESS_TOKEN':'bootstrap','TELEGRAM_BOT_TOKEN':'stale'}), patch.object(app,'load_env_file',side_effect=AssertionError('legacy fallback')), patch.object(app.subprocess,'run') as run:
            run.side_effect=[Mock(returncode=0,stdout=json.dumps({app.TOKEN_ENV:'first',app.CHAT_ENV:'destination'})),Mock(returncode=0,stdout=json.dumps({app.TOKEN_ENV:'second',app.CHAT_ENV:'destination'}))]
            self.assertEqual(app.configure_telegram(),'destination')
            self.assertEqual(os.environ[app.GENERIC_TOKEN_ENV],'first')
            app.configure_telegram()
            self.assertEqual(os.environ[app.GENERIC_TOKEN_ENV],'second')
            for call in run.call_args_list:
                self.assertNotIn('BWS_ACCESS_TOKEN',call.kwargs['env'])
                self.assertNotIn('TELEGRAM_BOT_TOKEN',call.kwargs['env'])

    def test_vault_failure_keeps_retry_queue_without_transport_or_secret_diagnostics(self):
        app=self.app
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ,{'T7_TELEGRAM_REFERENCE':'FEDORA_TELEGRAM_ENV'}), patch.object(app,'load_env_file',side_effect=AssertionError('legacy fallback')), patch.object(app.subprocess,'run',return_value=Mock(returncode=1,stderr='secret-canary')), patch.object(app,'send_message') as send:
            record={'job_id':'job-1','kind':'success','title':'fixture','message':'fixture'}
            self.assertFalse(app.send_record(Path(tmp),record))
            send.assert_not_called()
            queued=(Path(tmp)/'queue'/'job-1-success.json').read_text()
            self.assertNotIn('secret-canary',queued)
            self.assertIn('Bitwarden credential unavailable',queued)
