# Come è stata ricavata la mappa

Script usati una volta per costruire `assets/data/mappa.json` dall'immagine del tabellone del modulo TTS
(`board.png`, 3200x2977), in quest'ordine:

1. `detect.py`: trova punti colorati, ovali di penalità, caselle (orbite e "?") e cerchi di navigazione dai colori.
2. `edges.py`: scheletro delle piste grigie fra i punti; ogni tratto che tocca due punti è un sentiero.
3. `build_graph.py`: le estremità libere dei tratti diventano città di superficie e asteroidi.
4. `final_graph.py`: correzioni a mano (controllate zona per zona con `render.py`), uscite dei cerchi di
   navigazione, il reticolo del Sistema di Asteroidi, valori delle penalità.
5. `export_map.py`: sistemi, nomi delle orbite e scrittura del JSON.
