# Troubleshooting

- `exit 20`: T7 fisico assente o seriale persistente mancante.
- `exit 21`: `/mnt/T7_BACKUP` non è un mount; non creare file lì.
- `exit 22..30`: identità, filesystem o mount non sicuri; verificare `findmnt`,
  `lsblk` e `/dev/disk/by-id` senza usare `/dev/sdX` come configurazione.
- `exit 40`: credenziale systemd non caricata; usare service o `systemd-run`.
- `exit 50`: altro job attivo; non rimuovere lock mentre un processo lavora.
- `exit 60`: repository assente/incompleto; non reinizializzare sopra dati.
- Log: `sudo journalctl -u t7-restic-backup.service -n 200`.
