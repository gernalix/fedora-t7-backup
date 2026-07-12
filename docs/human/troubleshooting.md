# Troubleshooting

- `exit 20`: T7 fisico o partizione persistente assenti dopo l'attesa.
- `exit 21..24`: seriale, modello, filesystem o UUID non coincidono; non
  forzare il job e non usare `/dev/sdX` come configurazione.
- `exit 30..33`: mount, repository o spazio non sicuri. Verificare `findmnt`,
  `lsblk` e `/dev/disk/by-id`; non creare file in `/mnt/T7_BACKUP` smontato.
- `exit 40`: stato delle manutenzioni invalido; non correggerlo durante un job.
- `exit 50..51`: lo smontaggio non è riuscito; non scollegare. Controllare
  `fuser -vm /mnt/T7_BACKUP` e i log senza terminare processi estranei.
- `exit 97`: fault injection controllata; non è un codice operativo normale.
- `duplicate_event=ignored`: un secondo evento udev ha trovato il lock `/run`;
  il job già attivo continua e non va interrotto.
- Log: `sudo journalctl -u t7-restic-backup.service -n 200`.
