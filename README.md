# Quote Abbonamenti (web)

Web app per tenere traccia degli abbonamenti condivisi (Spotify, Netflix…): chi ti deve quanto ogni mese, chi ha già pagato, promemoria con il messaggio TWINT già pronto per WhatsApp o SMS.

Funziona sul telefono come un'app vera: si aggiunge alla schermata Home e funziona anche offline. I dati restano **solo sul tuo dispositivo** (nessun server, nessun account).

## Metterla nella schermata Home dell'iPhone
1. Apri il link della pagina in **Safari**.
2. Tocca **Condividi** (il quadrato con la freccia) › **Aggiungi alla schermata Home** › **Aggiungi**.
3. Aprila dall'icona: si apre a schermo intero, come un'app.

Su Android: Chrome › menu ⋮ › **Aggiungi a schermata Home** (oppure usa l'APK).

## Pubblicarla con GitHub Pages
Settings › Pages › Source: **Deploy from a branch** › Branch **main**, cartella **/ (root)** › Save. Dopo un minuto la pagina è su `https://<utente>.github.io/quote-abbonamenti-web/`.

## Note
- Esporta ogni tanto un **backup** (Impostazioni › Backup): se cancelli i dati di Safari o l'app dalla Home, i dati vanno persi.
- Nella versione web non ci sono notifiche programmate né blocco con Face ID: per quelle serve l'app nativa.

## File
- `index.html` — tutta l'app (HTML, CSS e JavaScript, nessuna libreria esterna)
- `manifest.webmanifest`, `icons/` — nome e icone per la schermata Home
- `sw.js` — funzionamento offline
