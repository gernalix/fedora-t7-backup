# Registro incidenti

## Mountpoint T7 ricaduto sul disco interno — risolto

Durante l'attività 583921 `/mnt/T7_BACKUP` esisteva ma il T7 non era montato.
Il job ora richiede mount separato e identità persistente completa prima di
accedere al repository. Il test di assenza deve restare obbligatorio.
