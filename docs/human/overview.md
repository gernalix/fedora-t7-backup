# Fedora T7 Backup

Il Samsung chiamato semplicemente **T7** ospita un repository Restic cifrato in
`/mnt/T7_BACKUP/restic-fedora`. Il backup protegge dati e configurazioni Fedora
con snapshot incrementali e deduplicati. Collegare il T7 avvia automaticamente
il job; a fine backup viene smontato e una notifica conferma quando scollegarlo.
Non è un clone settore-per-settore.

Vedere [OPERATIONS.md](OPERATIONS.md) per backup, restore, password, log e
disaster recovery; vedere [REPORT_684219.md](REPORT_684219.md) per l'audit corrente
e [REPORT_583921.md](REPORT_583921.md) per l'installazione iniziale.
