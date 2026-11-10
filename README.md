# Merchant of Venus, versione digitale

Versione digitale di **Merchant of Venus** (Avalon Hill, 1988, di Richard Hamblen, tabellone di Charles
Kibler): mercanti di specie diverse esplorano il Cluster, scoprono le culture nascoste del Primo Impero e
commerciano fra le stelle. Vince il primo che arriva al patrimonio stabilito (denaro più atti).

Si gioca nel browser: https://tannoiser2.github.io/Merchant-of-Venus/ (e dalla ludoteca https://tannoiser2.github.io).

## Cosa c'è

- **Gioco base completo** (regole 1-13 e lunghezze 14): movimento a punti con i dadi della nave, città di
  superficie da 2 PM, divieto di tornare indietro, atterraggi, ovali e segnalini di penalità con gli scudi,
  **cerchi di navigazione** con il numero pilota (anche il salto invisibile Corpo-Ala), **porte tele**,
  **propulsori** rosso, giallo e combinato che saltano i punti colorati, segnalini **"?"** (dieci reliquie,
  spazioporti aperti, porte tele, penalità), **osservazione** dalle orbite e **scoperta** con il pagherò,
  commercio con il limite in città e il soggiorno prolungato, **bicchiere** dei bonus (passeggeri e
  richieste), navi e permute, equipaggiamento, baratto, **atti** di spazioporti e fabbriche con lo sconto della
  propria specie, commissioni del 10% e del 50%.
- **Mappa 3D** con il tabellone originale del modulo Tabletop Simulator: pedine nei colori dei sei mercanti,
  segnalini "?" che si girano, spazioporti e fabbriche dei giocatori, schede delle culture scoperte nei
  riquadri con merci, bonus e reliquie accanto. Durante il movimento i punti raggiungibili sono cerchiati con
  il costo in PM.
- **Segnalini e carte in italiano** nello stile originale (tratteggio e colori dei segnalini Avalon Hill):
  culture, merci, merci di fabbrica, passeggeri, richieste, reliquie, porte tele, spazioporti aperti,
  equipaggiamento e le **carte nave** dei sei mercanti con le stive, dove si vedono le merci caricate.
  Le immagini senza testo (penalità, pagherò, creature, segnalini dei mercanti) sono quelle del modulo.
- Comandi della mappa con mouse e **tocco su iPad**: un dito trascina, due dita pizzicano per lo zoom e
  ruotano; rotella e tasto destro con il mouse; frecce, Q/E e +/- da tastiera.
- **Da 2 a 6 mercanti**, umani o computer: per il solitario si gioca contro i mercanti dell'**IA**, che
  esplora tutte le strade possibili con i dadi tirati e valuta mercati, passeggeri, navi e atti.
  **Gioco a turno** sullo stesso dispositivo, **online** con gli amici (Firebase) e **salvataggi** con un
  codice di sei lettere.
- Regolamento in italiano e tabelle dentro il gioco (`assets/regole.md`).

## Struttura

- `assets/data/mappa.json`: la mappa del Cluster ricavata dal tabellone (268 punti di movimento con tipo,
  colore, penalità e sistema, 322 sentieri, uscite dei cerchi di navigazione, orbite, città dello stesso
  pianeta). I punti sono stati riconosciuti dai colori dell'immagine e i sentieri dallo scheletro delle
  piste grigie, poi controllati e corretti a mano zona per zona.
- `scripts/data/mov_data.gd`: culture, merci, bonus, segnalini "?", navi, equipaggiamento, mercanti.
- `scripts/core/mappa.gd`, `engine.gd`, `ai.gd`: la mappa, le regole e l'avversario automatico.
- `scripts/ui/`: menu, partita (`game_view.gd`), mappa 3D (`board3d.gd`), regole e tabelle.
- `scripts/net/`: Firebase (stanze `merchantofvenus/rooms`, salvataggi `merchantofvenus/partite`) e partita
  online in lockstep. Usa le strutture comuni della ludoteca, quindi non servono regole nuove nel database.
- `tools/genera_segnalini.py`: prepara tabellone, segnalini e carte nave in italiano dal modulo TTS.

## Note

- Non ci sono le regole facoltative di combattimento (15), i Rastur e il solitario a flusso (16-17): il
  solitario si gioca contro l'IA. Non si dichiara il primo punto prima del tiro e non ci sono scambi
  diretti fra giocatori.
- I 48 bonus seguono l'elenco dei segnalini dell'edizione Avalon Hill (10 passeggeri e 38 richieste); le
  Piante da guardia rendono $140 come sulle carte di riferimento (FAQ).

## Prove

```
godot --headless --path . -s tests/autoplay.gd -- 5 3 1     # partite IA contro IA (partite, giocatori, seme)
godot --headless --path . -s tests/salva_carica.gd          # un salvataggio rigioca la stessa partita
sh tests/prova_online.sh godot                              # partita online completa sul finto Firebase
xvfb-run godot --path . -s tests/ui_auto.gd -- 8 /tmp       # interfaccia con un giocatore umano, con foto
xvfb-run godot --path . -s tests/tocco.gd                   # tocco su iPad e mouse sulla mappa
xvfb-run godot --path . -s tests/shot.gd -- 4 /tmp/foto.png 0
python3 tools/controlla_glifi.py                            # ogni carattere esiste nei font
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions, Pubblica, Run workflow) oppure con un commit su `main` il cui
messaggio contiene `[pubblica]`: costruisce la versione web con Godot 4.7 e la mette su GitHub Pages (e sulla
ludoteca privata Cloudflare se ci sono i segreti).
