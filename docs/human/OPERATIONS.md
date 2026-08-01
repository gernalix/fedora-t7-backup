# Operazioni Fedora T7 Backup — attività 684219

## Identità e architettura

Il dispositivo si chiama semplicemente **T7** nel contesto operativo. Fedora lo verifica come
`Samsung PSSD T7 Shield`, seriale `S6YGNS0Y903440H`, UUID
`4c75ac03-4c73-43f8-afd9-f90db49a74fc`, ext4 label `T7_BACKUP`, montato in
`/mnt/T7_BACKUP`. Un supporto recovery storico distinto non è il T7 e non deve
mai essere usato come destinazione.

Il repository `/mnt/T7_BACKUP/restic-fedora` è cifrato da Restic. La password è
custodita nel file canonico
`/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password`
(`daniele:daniele 0600`) e consegnata da systemd al servizio tramite una
credenziale privata in RAM. Il job rifiuta
mount assente, UUID/label/seriale/modello errati o mount ricaduto sul disco
interno.

## Collegamento automatico, stato e backup manuale

Tenere normalmente il T7 scollegato. Il collegamento USB del seriale corretto
attiva udev, che delega a `t7-restic-backup.service`. Il servizio attende la
partizione, monta, verifica identità/repository/spazio, esegue backup+retention,
le manutenzioni dovute, `sync`, smonta e invia Telegram. Scollegare solo dopo la
notifica di successo. Se fallisce, leggere la notifica: `Può essere scollegato:
no` significa che il mount non è stato chiuso.

```bash
systemctl status t7-restic-backup.service t7-restic-reminder.timer
sudo systemctl start t7-restic-backup.service
sudo journalctl -u t7-restic-backup.service -n 200
findmnt /mnt/T7_BACKUP
lsblk -o NAME,TYPE,FSTYPE,UUID,MOUNTPOINTS
```

Ogni collegamento crea un backup. `forget` applica 7 giornalieri, 5 settimanali,
12 mensili e 3 annuali. State esplicito `0600` limita check 5% e prune a una
volta/settimana e check completo a una volta/mese. Dopo successo, il reminder
one-shot a 30 minuti notifica solo se il seriale è ancora sul bus.

Disabilitare temporaneamente il trigger: rinominare con prudenza la regola
`/etc/udev/rules.d/90-t7-name.rules`, poi `sudo udevadm control --reload-rules`;
ripristinarla e ricaricare per riattivare. Non modificare UUID/seriale.

## Elencare snapshot e statistiche

Avviare un comando transiente che riceve la credenziale senza mostrarla:

```bash
sudo systemd-run --wait --pipe --collect --unit=t7-restic-snapshots \
  -p LoadCredential=restic-password:/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password \
  /usr/local/libexec/t7-restic-backup snapshots
sudo systemd-run --wait --pipe --collect --unit=t7-restic-stats \
  -p LoadCredential=restic-password:/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password \
  /usr/local/libexec/t7-restic-backup stats
```

## Ripristinare un file o una directory

Il target deve non esistere. Sostituire il path incluso con quello desiderato:

```bash
sudo systemd-run --wait --pipe --collect --unit=t7-restic-restore \
  -p LoadCredential=restic-password:/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password \
  /usr/local/libexec/t7-restic-backup restore latest /var/tmp/t7-restore /home/daniele/Documents/file.txt
sudo find /var/tmp/t7-restore -maxdepth 5 -ls
```

Verificare il contenuto, copiarlo nella destinazione con ownership corretta e
poi rimuovere manualmente `/var/tmp/t7-restore`.

## Ripristinare l'intera home

Su un sistema funzionante, fermare applicazioni che scrivono nella home e
ripristinare prima in una directory separata:

```bash
sudo systemd-run --wait --pipe --collect --unit=t7-restic-restore-home \
  -p LoadCredential=restic-password:/home/daniele/.config/codex/secrets/fedora_t7_backup.restic_password \
  /usr/local/libexec/t7-restic-backup restore latest /var/tmp/t7-home-restore /home
```

Confrontare, quindi sincronizzare offline solo i dati desiderati. Non
ripristinare direttamente sopra una home attiva.

## Disaster recovery Fedora

1. Installare Fedora e Restic; non formattare il T7.
2. Montare l'ext4 UUID atteso in `/mnt/T7_BACKUP` e verificare modello/seriale.
3. Recuperare il file password canonico o la copia di sicurezza verificata e
   impostarlo `0600`; non rigenerare o sostituire la password.
4. Usare `RESTIC_PASSWORD_FILE` con un file `0600` in tmpfs e `restic -r
   /mnt/T7_BACKUP/restic-fedora snapshots`.
5. Ripristinare prima `/var/lib/t7-restic-backup/manifest` e usare elenchi RPM,
   Flatpak, mount, boot, SELinux e systemd per ricostruire Fedora.
6. Ripristinare `/etc`, dati applicativi, home e gli altri path in staging;
   applicare ownership e SELinux con attenzione; reinstallare bootloader e
   pacchetti secondo il nuovo sistema.

## Conservare e cambiare password

Il file canonico non va stampato, passato come argomento, copiato nei repository
o rigenerato dall'installer. Prima di qualsiasi rotazione, conservarne una copia
esterna verificata, usare `restic key passwd` con file privati `0600`, testare
listing e restore read-only, quindi sostituire atomicamente il file canonico.
La rotazione richiede un'azione umana esplicita; non rimuovere la vecchia chiave
prima della prova di recuperabilità.

## Inclusioni, esclusioni e database

Inclusi: `/home`, `/root`, `/etc`, `/usr/local`, `/opt`, `/var/lib`,
`/var/spool`, `/var/www`, `/srv`, `/boot`. Esclusi: cache, Trash, SDK Android
scaricabile, repository Flatpak, coredump, layer immagine Podman, filesystem
virtuali, tmp, swap, T7 e repository stesso. Mount annidati non vengono seguiti.

Il database SQLite attivo di Fedora System Monitor viene copiato online e
verificato prima del backup; i file DB/WAL/SHM live sono esclusi. Non sono stati
rilevati PostgreSQL, MariaDB/MySQL, Datasette, Uptime Kuma locale, container o
volumi. Un backup Restic è filesystem-level: recupera dati e configurazioni, ma
non è un'immagine raw identica del disco.

## T7 scollegato, visibilità e rimozione

Con T7 scollegato il servizio fallisce visibilmente prima di scrivere. Il mount
`fstab` sotto `/mnt` può non comparire automaticamente in Nautilus; aprire
`/mnt/T7_BACKUP` con `Ctrl+L` o usare il bookmark T7.

Disattivazione conservativa:

```bash
sudo ./scripts/uninstall.sh
```

Lo script preserva repository, password canonica, configurazione, stato e cache.
La cancellazione di questi elementi è separata, manuale e distruttiva.
