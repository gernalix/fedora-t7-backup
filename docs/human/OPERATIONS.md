# Operazioni Fedora T7 Backup — attività 583921

## Identità e architettura

Il dispositivo si chiama semplicemente **T7** nel contesto operativo. Fedora lo verifica come
`Samsung PSSD T7 Shield`, seriale `S6YGNS0Y903440H`, UUID
`4c75ac03-4c73-43f8-afd9-f90db49a74fc`, ext4 label `T7_BACKUP`, montato in
`/mnt/T7_BACKUP`. Una vecchia chiavetta recovery può avere label vfat
`VEEAMRE`: non è il T7 e non deve mai essere usata come destinazione.

Il repository `/mnt/T7_BACKUP/restic-fedora` è cifrato da Restic. La password è
custodita in `/etc/credstore.encrypted/t7-restic-password` (`root:root 0600`) e
decrittata da systemd solo in RAM per la durata del servizio. Il job rifiuta
mount assente, UUID/label/seriale/modello errati o mount ricaduto sul disco
interno.

## Stato, log e backup manuale

```bash
systemctl list-timers 't7-restic-*'
systemctl status t7-restic-backup.timer t7-restic-check.timer t7-restic-maintenance.timer
sudo systemctl start t7-restic-backup.service
sudo journalctl -u t7-restic-backup.service -u t7-restic-check.service -u t7-restic-maintenance.service
```

Frequenze: backup giornaliero alle 03:00, check casuale del 5% domenica alle
06:00, check completo e prune il primo giorno del mese alle 07:00; ogni timer ha
jitter ed è `Persistent=true`. Retention: 7 giornalieri, 5 settimanali, 12
mensili, 3 annuali, raggruppati per host e path.

## Elencare snapshot e statistiche

Avviare un comando transiente che riceve la credenziale senza mostrarla:

```bash
sudo systemd-run --wait --pipe --collect --unit=t7-restic-snapshots \
  -p LoadCredentialEncrypted=restic-password:/etc/credstore.encrypted/t7-restic-password \
  /usr/local/libexec/t7-restic-backup snapshots
sudo systemd-run --wait --pipe --collect --unit=t7-restic-stats \
  -p LoadCredentialEncrypted=restic-password:/etc/credstore.encrypted/t7-restic-password \
  /usr/local/libexec/t7-restic-backup stats
```

## Ripristinare un file o una directory

Il target deve non esistere. Sostituire il path incluso con quello desiderato:

```bash
sudo systemd-run --wait --pipe --collect --unit=t7-restic-restore \
  -p LoadCredentialEncrypted=restic-password:/etc/credstore.encrypted/t7-restic-password \
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
  -p LoadCredentialEncrypted=restic-password:/etc/credstore.encrypted/t7-restic-password \
  /usr/local/libexec/t7-restic-backup restore latest /var/tmp/t7-home-restore /home
```

Confrontare, quindi sincronizzare offline solo i dati desiderati. Non
ripristinare direttamente sopra una home attiva.

## Disaster recovery Fedora

1. Installare Fedora e Restic; non formattare il T7.
2. Montare l'ext4 UUID atteso in `/mnt/T7_BACKUP` e verificare modello/seriale.
3. Recuperare la password dal password manager, non dalla sola credenziale
   cifrata legata al vecchio host.
4. Usare `RESTIC_PASSWORD_FILE` con un file `0600` in tmpfs e `restic -r
   /mnt/T7_BACKUP/restic-fedora snapshots`.
5. Ripristinare prima `/var/lib/t7-restic-backup/manifest` e usare elenchi RPM,
   Flatpak, mount, boot, SELinux e systemd per ricostruire Fedora.
6. Ripristinare `/etc`, dati applicativi, home e gli altri path in staging;
   applicare ownership e SELinux con attenzione; reinstallare bootloader e
   pacchetti secondo il nuovo sistema.

## Conservare e cambiare password

Passaggio manuale obbligatorio dopo l'installazione: in un terminale privato,
decrittare la credenziale direttamente nel password manager senza salvarla su
disco persistente:

```bash
sudo systemd-creds decrypt --name=restic-password /etc/credstore.encrypted/t7-restic-password -
```

Non incollare l'output in chat, log o repository; pulire il terminale. Per
cambiare password, aprire una root shell privata e usare file temporanei in
`/run` con `umask 077`: decrittare la vecchia password, creare la nuova con
`openssl rand -base64 48`, eseguire `restic key passwd --password-file OLD
--new-password-file NEW`, cifrare `NEW` con `systemd-creds encrypt
--with-key=host --name=restic-password`, sostituire atomicamente la credenziale,
testare `snapshots`, quindi eliminare entrambi i file in `/run`. Non rimuovere la
vecchia chiave prima del test.

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

Lo script preserva repository, password cifrata, configurazione, stato e cache.
La cancellazione di questi elementi è separata, manuale e distruttiva.
