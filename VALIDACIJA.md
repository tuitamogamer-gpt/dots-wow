# Provjera verzije 0.1.0

Datum: 4. listopada 2026.

- **22 Python/Lua testa prolaze.** Koristi se stvarni Lua 5.1 runtime (`lupa.lua51`), uz simulirane WoW API-je. Pokriveni su učitavanje, stanje razgovora, klikovi kroz mock sučelje, limiti UTF-8 teksta, izbjegavanje zaštićenih vrijednosti i podataka u borbi, pogrešni i ponovljeni odgovori, prikaz WoW oznaka kao teksta te obnova aktivnog pitanja nakon reloada.
- U tom broju je i **prijenos kroz oba stvarna protokola**: Lua priprema pitanje → JavaScript companion obrađuje pitanje i odgovor → Lua uvozi odgovor. Provjereni su hrvatski znakovi, emoji i višeredni tekst.
- **8 Node.js testova prolazi.** Pokriveni su zaglavlja i ID-evi, byte limiti, odgovori unutar Markdown ograde, priprema običnog teksta i dopuštene ChatGPT adrese.
- **Chromium provjera kroz lokalni HTTP**: priprema odgovora, odbijanje pogrešnog ID-a, poništavanje pripremljenog odgovora nakon izmjene, ručno kopiranje kad Clipboard API nije dostupan, validacija adrese, bez trajnog spremanja razgovora, prikaz širine 375 px bez vodoravnog prelijevanja. Nisu zabilježene JavaScript greške ni vanjski mrežni zahtjevi prije korisničkog otvaranja dota.
- TOC datoteka navodi postojeće datoteke i `Interface: 16001`. XML tipkovničkog prečaca je sintaktički valjan.

## Što još nije provjereno

- Rad u stvarnom WoW: Forever beta klijentu, izgled WoW prozora, nativne secret vrijednosti i stvarna pohrana SavedVariables.
- Razgovor u korisnikovu osobnom DOTS računu i stvarni glasovni poziv. Ti se koraci odvijaju u njegovu prijavljenom ChatGPT-u.
- Otvaranje companion stranice preko `file://` u ovom okruženju: upravljani Chromium to blokira pravilom administratora. Pravilo nije mijenjano. Stranica je zato provjerena preko `127.0.0.1`; koristi obične lokalne skripte, bez modula ili `fetch` poziva. README sadrži i lokalni HTTP način otvaranja.

Automatizirani testovi potvrđuju provjerene dijelove implementacije, a ne certifikaciju kompatibilnosti s budućim beta buildovima.
