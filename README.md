# DOTS Forever

WoW: Forever addon za razgovor s tvojim stvarnim OpenAI dotom. Otvara se naredbom **`/dots`** ili tipkovničkim prečacem koji odabereš u WoW postavkama.

**Verzija 0.1.0 · namijenjeno Forever beti, Interface 16001.** Kod i prijenos poruka provjeravaju se automatiziranim testovima; rad unutar samog WoW klijenta još nije provjeren.

## Instalacija

1. Raspakiraj ZIP. Mapu **`DOTSForever`** kopiraj u mapu `Interface/AddOns` svog **Forever** klijenta. U aktualnoj beti to je obično:

   ```text
   World of Warcraft/_classic_beta_/Interface/AddOns/DOTSForever/DOTSForever.toc
   ```

   U Battle.netu odaberi Forever betu i otvori njezinu instalacijsku mapu. Ne kopiraj cijeli paket u `AddOns`; tamo ide samo mapa `DOTSForever`.

2. Pokreni ili ponovno pokreni WoW. Na zaslonu odabira lika, u **AddOns**, uključi **DOTS Forever**.
3. U igri upiši **`/dots`**.
4. Izvan igre otvori **`companion/index.html`** dvoklikom. To je lokalna pomoćna stranica; ne treba instalaciju, poslužitelj, API ključ ni internet za obradu teksta. Za sam razgovor s dotom potrebna je internetska veza i tvoj prijavljeni ChatGPT račun s dostupnim dotom.

## Kako razgovarati

1. U addonu napiši pitanje i odaberi **Pripremi poruku**.
2. Pritisni **Ctrl+C** i zalijepi poruku na lokalnoj companion stranici.
3. Na companion stranici kopiraj poruku i otvori svog dota. **U njegov razgovor zalijepi i pošalji poruku.** Time se koristi tvoj postojeći dot i njegov kontekst.
4. Kopiraj stvarni odgovor dota na companion stranicu. Ona priprema odgovor za povratak u WoW.
5. U igri odaberi **Uvezi odgovor**, zalijepi pripremljeni tekst i klikni **Dodaj odgovor**.

Companion može zapamtiti adresu razgovora s tvojim dotom. Ako je još nemaš, otvara službenu stranicu [chatgpt.com/dots](https://chatgpt.com/dots), gdje odabereš svog dota. Stranica ne šalje poruku umjesto tebe.

**Može i bez companion stranice:** tekst iz addona zalijepi izravno u razgovor sa svojim dotom. Poruka ga traži da odgovoru doda `DOTS_REPLY:<ID>` kao prvi redak. Kopiraj cijeli odgovor sa zaglavljem u addon. Ako dot izostavi zaglavlje, companion ga može dodati.

Na macOS-u upotrijebi odgovarajući prečac za kopiranje/lijepljenje (u pregledniku **⌘C / ⌘V**). Ako preglednik ne dopusti gumbu pristup međuspremniku, stranica označi tekst i prikaže uputu za ručno kopiranje.

## Glasovni poziv

Otvori svog dota kroz companion stranicu, pa **u ChatGPT razgovoru klikni ikonu telefona**. Službeni poziv radi u ChatGPT-u; addon sam ne otvara mikrofon niti pokreće poziv. U desktop aplikaciji poziv je dostupan i kroz **Call** u profilu dota. Razgovor može ostati otvoren dok igraš.

## Naredbe

| Naredba | Radnja |
| --- | --- |
| `/dots` ili `/dot` | Otvori/zatvori prozor. |
| `/dots ask Kako da nastavim ovaj quest?` | Pripremi pitanje za dota. |
| `/dots import` | Otvori unos odgovora. |
| `/dots cancel` | Otkaži aktivno pitanje u addonu. |
| `/dots clear` | Obriši lokalni razgovor i aktivno pitanje. |
| `/dots reset` | Vrati prozor na sredinu zaslona. |
| `/dots version` | Prikaži verziju klijenta, build i Interface broj. |
| `/dots help` | Kratke upute u chatu. |

Tipkovnički prečac postavljaš u WoW izborniku za tipke pod **DOTS Forever → Otvori / zatvori DOTS agenta**. Prečac nije unaprijed zauzet. Prozor možeš pomicati povlačenjem njegova okvira. Kotačićem miša pregledavaš povijest.

## Što se prenosi i sprema

- Zadano se prenosi samo pitanje. Opcija **Dodaj klasu, razinu i zonu** dodaje još verziju klijenta; taj se kontekst prikuplja pri pripremi poruke, samo izvan borbe. Ne prikupljaju se chat drugih igrača, ime lika, realm, meta, zdravlje ni podaci o borbi. Zaštićene API vrijednosti preskaču se.
- Poruku pregledaš prije slanja. Addon nema HTTP vezu, pristup ChatGPT računu ni API ključ.
- Addon sprema do 30 lokalnih zapisa, aktivno pitanje, položaj prozora i postavku konteksta, zasebno po liku, kroz WoW SavedVariables. WoW ih zapisuje pri odjavi ili `/reload`; izlazak zbog rušenja može izgubiti zadnje promjene.
- Lokalna companion stranica pohranjuje samo odabranu ChatGPT adresu. Tekst razgovora ostaje u memoriji otvorene stranice, bez slanja na poslužitelj. Kopiranje koristi međuspremnik tvog sustava.
- `/dots cancel` i `/dots clear` odnose se na addon. Ne brišu ChatGPT razgovor niti zaustavljaju dotov rad u ChatGPT-u.
- Odgovor se prikazuje kao tekst. Addon ne izvršava Lua kod, makroe ni poteze u igri.

## Ograničenja i rješavanje problema

**Ovo je ručna veza sa stvarnim dotom.** Standardni WoW addon ne može slati proizvoljne HTTP zahtjeve ni pokretati preglednik ili vanjsku aplikaciju. Dokumentirani načini kontakta s dotom su ChatGPT, Slack, Teams i poziv u ChatGPT-u; javni API za izravan poziv tvog osobnog dota nije potvrđen. Zato ova verzija ne koristi izmišljeni endpoint niti zamjenjuje tvog dota običnim API chatbotom.

U tijeku može biti jedno pitanje. Dok čekaš odgovor, gumb **Kopiraj poruku** ponovno prikazuje isti zahtjev. Za novo pitanje uvezi odgovor ili otkaži prethodno. ID u zaglavlju sprječava slučajan uvoz odgovora na drugo pitanje. To je oznaka uparivanja, ne kriptografska potvrda autora; uvozi tekst iz svog stvarnog razgovora.

Pitanje može imati do 2000 UTF-8 bajtova, a odgovor do 6000. Slova s dijakritikom mogu zauzeti više od jednog bajta. Za predug odgovor zatraži kraću verziju od dota.

Ako addon nedostaje na popisu, provjeri da `.toc` nije u dvostrukoj mapi `DOTSForever/DOTSForever`. Ako je označen kao zastario, beta možda koristi drugi Interface broj. Provjeri ga naredbom `/dump select(4, GetBuildInfo())`. Ova verzija cilja **16001**; označavanje novijeg builda u `.toc` samo po sebi ne potvrđuje kompatibilnost API-ja. Za privremenu provjeru klijent može nuditi **Load out of date AddOns**.

Ako preglednik blokira lokalne HTML datoteke, možeš koristiti izravan prijenos addon → ChatGPT ili, uz instaliran Python 3, pokrenuti sljedeću naredbu iz raspakiranog paketa i otvoriti `http://127.0.0.1:8766`:

```sh
python3 -m http.server 8766 --bind 127.0.0.1 --directory companion
```

Na Windowsu naredba može biti `py -m http.server 8766 --bind 127.0.0.1 --directory companion`. Poslužitelj zaustavi s Ctrl+C.

## Razvoj i provjera

Addon nema vanjske Lua biblioteke. Companion nema npm ovisnosti i koristi lokalne HTML, CSS i JavaScript datoteke. Za razvojne testove trebaju Python 3 s paketom `lupa` i Node.js:

```sh
python3 -m pip install lupa
python3 -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/test_companion.cjs
```

Prije stvarnog korištenja u beta klijentu provjeri: učitavanje bez Lua greške, `/dots`, otvaranje i povratak odgovora, prečac, pomicanje prozora, `/reload` i očuvanje aktivnog pitanja. Automatizirana provjera s mock WoW API-jima ne može potvrditi prikaz i ponašanje u samoj igri.

## Izvori za odabrano povezivanje i klijent

Provjereno 4. listopada 2026.:

- [OpenAI: kontakt s dotom i glasovni pozivi](https://learn.chatgpt.com/docs/dots/channels)
- [OpenAI: predstavljanje dotsa](https://openai.com/index/introducing-dots/)
- [Blizzard: World of Warcraft: Forever](https://worldofwarcraft.blizzard.com/en-us/forever)
- [Provjera Interface 16001 na Forever beta klijentu](https://github.com/arkayenro/arkinventory/issues/2162)
- [Forever i moderna ograničenja addon API-ja](https://www.wowhead.com/news/wow-forever-will-have-addon-changes-from-midnight-382921)

Neslužbeni dodatak zajednice; nije proizvod Blizzarda ni OpenAI-ja.
