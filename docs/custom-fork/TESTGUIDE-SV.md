# Testa Meeting Transcriber på din Mac — från början

Den här guiden är skriven för dig som inte har byggt eller testat en app tidigare. Du behöver inte kunna programmera. Följ stegen i ordning och stanna vid ett fel; du ska inte behöva gissa hur du lagar kod.

**Detta är ett utkast. Appen har ännu inte byggts eller körts på en Mac av mig.** 31 tester av de delar som går att köra i molnmiljön har passerat. Guiden hjälper oss att upptäcka både byggfel och problem i den riktiga Mac-appen.

All kod hämtas från **din fork, `iAmYoel/meeting-transcriber`**, på branchen **`codex/obsidian-meeting-workflow`**. Du behöver inte skapa eller slå ihop en PR för att testa branchen. Ursprungliga skaparens repository berörs inte.

## Så använder du guiden

Ta gärna två pass: först installation, bygge och test med påhittad text; sedan inspelning och kalender. Första installationen kan ta en eller flera timmar beroende på internet och hämtningar. Senare starter går snabbare.

När du ser en ruta med kommandon:

1. Öppna appen **Terminal** enligt steg 2.
2. Kopiera bara innehållet i rutan, inte texten runtomkring eller tecknen som avgränsar rutan.
3. Klistra in med **⌘V**. Tryck **Retur** om kommandot inte startar direkt.
4. Vänta tills det är klart innan du går vidare. Terminalen visar då åter en rad där du kan skriva, ofta med `%` i slutet.

Det är normalt att Terminal visar många engelska rader. **Resultatkod 0 betyder att kommandot lyckades. Alla andra resultatkoder betyder att du ska stanna vid det steget.** En tom logg är däremot inte automatiskt ett lyckat test.

Om ett kommando verkar fastna kan du avbryta det med **Ctrl+C**. Gör det inte bara för att ett bygge är tyst en stund. Första hämtningen och bygget kan ta tiotals minuter. Om du är osäker, skicka det du ser så hjälper jag dig.

### Några ord du kommer att se

| Ord | Vad det betyder här |
| --- | --- |
| Fork | Din egen kopia av projektet på GitHub. |
| Branch | En version av koden. Vi testar vår nya branch utan att ändra `main`. |
| Bygga | Låta Macen omvandla koden till en app som kan startas. |
| Xcode / Swift | Apples verktyg som utför bygget. |
| Vault | Mappen där Obsidian sparar dina anteckningar. Vi använder en ny testmapp. |
| Transkript | Den fullständiga texten av det som sagts. |
| Ollama / modell | Verktyget och den lokala AI-modellen som skriver sammanfattningen. |
| WhisperKit | Verktyget som omvandlar inspelat ljud till text. Det är en annan modell än sammanfattningsmodellen. |
| Pending | Färdig text som väntar på att du ska begära en sammanfattning. |
| Archive | Platsen dit texten flyttas efter att mötesanteckningen har sparats säkert. |
| Logg | En textfil som visar vad ett bygge eller test gjorde och eventuella fel. |

## 1. Förbered Macen och installera verktygen

Anslut gärna laddaren och ha internet tillgängligt. Xcode, byggets hjälpbibliotek och AI-modeller tar plats. Ha gärna minst 40 GB ledigt som praktisk marginal; exakt behov varierar.

Kontrollera macOS-versionen via ** → Om den här datorn**. Anteckna versionen och att datorn är en Apple Silicon-Mac, exempelvis M2 Pro. Själva appen kräver macOS 14.2 eller senare, men **Xcode 26 eller senare kan kräva en nyare macOS-version**. App Store visar vad den Xcode-version du hämtar kräver. Om din Mac inte kan installera den, stanna och skicka macOS-versionen; installera inte bara äldre Xcode och fortsätt ändå.

Installera följande, om du inte redan har dem:

1. **Xcode:** öppna App Store, sök efter **Xcode**, kontrollera att utgivaren är Apple och installera. Vi behöver Xcode 26 eller senare med Swift 6.2 eller senare. Bara den mindre produkten “Command Line Tools” räcker inte för den här guiden.
2. Öppna Xcode när installationen är klar. Godkänn Apples villkor och låt efterfrågade komponenter installeras. Om du får välja plattformar behövs macOS; du behöver inte hämta alla mobilplattformar för detta projekt. Stäng Xcode efter att den första installationen är klar. Du behöver inte skapa ett nytt projekt där.
3. **GitHub Desktop:** hämta från <https://desktop.github.com/>. Lägg appen i **Program** om installationsfönstret ber dig göra det. Öppna den och logga in på GitHub med kontot som har tillgång till din fork. Verktyget hjälper oss att hämta rätt kod utan att hantera lösenord i Terminal.
4. **Obsidian:** hämta från <https://obsidian.md/download>, installera och öppna. Vi väljer testmappen senare.
5. **Ollama:** hämta Mac-versionen från <https://ollama.com/download/mac>, installera och öppna. Följ dess instruktioner för att göra kommandot `ollama` tillgängligt. Om macOS frågar om tillstånd att lägga till kommandot, är det detta vi ska använda i steg 9.

Du behöver inte köpa ett Apple Developer-medlemskap för att prova det lokala utvecklingsbygget. Du behöver inte heller installera Homebrew för huvudstegen i den här guiden.

## 2. Öppna Terminal och kontrollera byggverktygen

Tryck **⌘mellanslag**, skriv **Terminal** och tryck Retur. Ett fönster med en textrad öppnas. Låt det vara öppet under guiden.

Kör dessa kommandon ett i taget:

```bash
xcodebuild -version
```

**Du ska se:** `Xcode 26...` eller en senare huvudversion, plus ett byggnummer. Om det står att Xcode krävs eller att utvecklarverktygen inte kan hittas, se felsökningen nedan.

```bash
swift --version
```

**Du ska se:** Swift-version **6.2 eller senare**. Texten kan även innehålla `Apple Swift` och `arm64`. Om versionen är äldre, stanna och skicka båda kommandonas utskrift.

Om Xcode är installerat i Program men första kommandot pekar på fel verktyg, kör:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Det här väljer den installerade Xcode som byggverktyg. `sudo` ber om **ditt vanliga Mac-inloggningslösenord**. Inga tecken eller prickar syns när du skriver det; det är normalt. Tryck Retur. Skicka aldrig lösenordet till mig. Om Xcode heter något annat eller ligger någon annanstans, stanna i stället för att ändra sökvägen på chans.

Öppna Xcode en gång till om ett fel säger att licensen eller första installationen inte är klar. Kör sedan de två versionskommandona igen.

## 3. Hämta rätt version från din fork

I **GitHub Desktop**:

1. Välj **File → Clone Repository…**.
2. Leta efter **`iAmYoel/meeting-transcriber`** under GitHub.com. Om den inte syns, välj fliken **URL** och ange `https://github.com/iAmYoel/meeting-transcriber.git`.
3. Välj **Local path** så att projektmappen hamnar på **`/Users/ditt-användarnamn/Documents/GitHub/meeting-transcriber`**. `Documents` visas ofta som **Dokument** i Finder. Använd ditt faktiska Mac-användarnamn; skriv inte bokstavligen `ditt-användarnamn`.
4. Klicka **Clone** och vänta tills hämtningen är klar.
5. Klicka på **Current Branch** högst upp. Sök efter och välj **`codex/obsidian-meeting-workflow`**. Om den inte syns, klicka **Fetch origin** och leta igen.
6. Om du redan hade projektet hämtat: klicka **Fetch origin**, välj branchen och använd **Pull origin** om Desktop erbjuder det. Om Desktop varnar för egna ändringar, stanna och skicka varningen. Kasta inte bort ändringarna.

**Du ska se:** rätt repository och `codex/obsidian-meeting-workflow` som aktuell branch. Välj inte `main` och använd inte knappar för att slå ihop eller skicka ändringar till ursprungsprojektet.

Om du redan har en kopia på en annan plats kan du behålla den. Då måste sökvägen i nästa steg ändras till den platsen; GitHub Desktop kan öppna projektet med **Repository → Open in Terminal**. Använd inte en annan sökväg bara för att en mapp råkar ha samma namn.

## 4. Öppna projektmappen i Terminal

Med standardplatsen från steg 3, kör:

```bash
cd "$HOME/Documents/GitHub/meeting-transcriber"
```

`cd` betyder “gå till den här mappen”. `$HOME` betyder din egen användarmapp, så du behöver inte skriva in ditt användarnamn.

Om du får `No such file or directory`, ligger projektet någon annanstans. Öppna det via GitHub Desktops **Repository → Open in Terminal** och använd det nya Terminal-fönstret för fortsättningen.

Kontrollera sedan:

```bash
git branch --show-current
```

**Du ska se exakt:**

```text
codex/obsidian-meeting-workflow
```

Kontrollera också adressen:

```bash
git remote get-url origin
```

**Du ska se:** en adress som innehåller **`iAmYoel/meeting-transcriber`**. Den kan börja med `https://` eller `git@github.com:`. Om ägaren är någon annan, stanna. Alla följande projektkommandon körs i detta Terminal-fönster och denna mapp.

## 5. Kör de första automatiska testerna

Ett automatiskt test kontrollerar en regel i koden åt oss. Detta första steg testar bland annat att texter inte tappas bort, att filer inte skrivs över och att sammanfattningar väntar på sin tur. Det startar inte appen och spelar inte in något.

Kopiera hela rutan:

```bash
./scripts/test_custom_core.sh > "$HOME/Desktop/MeetingTranscriber-karn-test.log" 2>&1
echo "Testets resultatkod: $?"
open -a TextEdit "$HOME/Desktop/MeetingTranscriber-karn-test.log"
```

Första raden kör testet och sparar all utskrift i en fil på skrivbordet. Därför kan Terminal vara tyst under körningen. Andra raden visar resultatkoden. Tredje raden öppnar filen i Textredigerare.

**Godkänt:** resultatkod **0**, och i loggen en rad med **`Executed 31 tests, with 0 failures`**. Längst ned kan dessutom stå `0 tests` från ett annat testsystem; det är raden om **31 XCTest-tester** som gäller här.

**Vid fel:** skicka filen `MeetingTranscriber-karn-test.log` och stanna innan nästa steg.

## 6. Kör Mac-appens automatiska tester

Det här steget försöker även kompilera appens Mac-kod. Första gången hämtas hjälpbibliotek från internet. Det kan ta betydligt längre tid än steg 5.

```bash
(cd app/MeetingTranscriber && swift test --parallel) > "$HOME/Desktop/MeetingTranscriber-app-test.log" 2>&1
echo "Testets resultatkod: $?"
open -a TextEdit "$HOME/Desktop/MeetingTranscriber-app-test.log"
```

**Godkänt:** resultatkod **0** och en slutrapport som säger att testerna passerade. Antalet är större än 31 och kan ändras när projektet uppdateras. Enstaka rader som `Build complete` räcker inte om testresultatet därefter är underkänt.

**Vid fel:** skicka `MeetingTranscriber-app-test.log`. Om du ser ett Swift-kompileringsfel är det ett problem att undersöka i utkastet; du ska inte behöva ändra koden själv.

## 7. Bygg appen utan att starta den

Nu gör vi en riktig app av koden. Kommandot nedan bygger appen men väntar med att öppna den, så byggresultatet blir tydligt.

```bash
./scripts/run_app.sh --build-only > "$HOME/Desktop/MeetingTranscriber-build.log" 2>&1
echo "Byggets resultatkod: $?"
open -a TextEdit "$HOME/Desktop/MeetingTranscriber-build.log"
```

**Godkänt:** resultatkod **0** och raden **`Bundle ready:`** följd av en sökväg som slutar med **`MeetingTranscriber-Dev.app`**.

En varning om **`no codesigning identity`** betyder att du saknar ett utvecklarcertifikat. Det är väntat på en Mac som aldrig använts för utveckling och är inte i sig ett misslyckat bygge. Macens behörigheter kan behöva godkännas på nytt när du bygger om. Om resultatkoden är annan än 0 gäller det fortfarande som fel, även om loggen också innehåller denna varning.

**Vid fel:** skicka `MeetingTranscriber-build.log`. Använd inte publicerings-, signerings- eller releasekommandon för att försöka lösa problemet.

## 8. Starta appen och hitta inställningarna

Kör:

```bash
open "app/MeetingTranscriber/.build/MeetingTranscriber-Dev.app"
```

Det här är en **menyradsapp**: den behöver inte öppna ett stort fönster. Leta efter dess ikon i menyraden längst upp på skärmen, nära klockan. Klicka på ikonen och välj **Settings...**.

Appen kan redan vid starten börja hämta eller läsa in sin förvalda ljudmodell. Det är separat från Ollama och kan ta tid första gången. Textimporttestet kräver ingen ljudinspelning, men en sådan bakgrundshämtning kan ändå pågå. Om ett modellfel visas, anteckna den exakta texten och vilket modellnamn som syns.

Om macOS blockerar starten eller varnar för appen, skicka den exakta texten. Stäng inte av Macens säkerhetsfunktioner för att komma vidare.

Macen kan fråga om mikrofon, skärm/systemljud eller notiser. I början testar vi bara textimport. Behörigheter för ljud behövs för inspelningstestet senare. Appens kalenderåtkomst ska inte behöva godkännas förrän du själv aktiverar den.

Välj **General** i inställningarnas vänsterspalt:

- **When a meeting is detected:** välj **Ask before recording**. Det betyder att du måste välja Record innan en upptäckt träff spelas in.
- **Record-only mode:** ska vara **av**. Detta läge hoppar annars över textbearbetning och gör andra inställningar grå.
- Under **Apps to Watch:** slå på **Microsoft Teams** om det är Teams du ska testa senare. Övriga appar kan vara av under första testet.
- **Use selected calendars:** lämna **av** tills vi kommer till kalendertestet.

Om menyn visar **Stop Watching**, klicka på den under första texttestet. Då övervakar appen inte pågående samtal medan vi konfigurerar den. Menyvalet blir **Start Watching** när övervakningen är stoppad.

Inställningarna sparas automatiskt. En tidigare installation kan ha andra val kvar, så kontrollera dem uttryckligen.

## 9. Installera en liten sammanfattningsmodell

Öppna **Ollama** om det inte redan är igång. Gå tillbaka till Terminal och kör:

```bash
ollama --version
```

**Du ska se:** ett versionsnummer. `command not found: ollama` betyder att Macen inte hittar kommandot; öppna Ollama och kontrollera installationen från steg 1. Öppna ett nytt Terminal-fönster om installationen just lagt till kommandot. Gå i så fall till projektmappen igen enligt steg 4.

Hämta modellen för det första testet:

```bash
ollama pull qwen2.5:3b
```

Detta hämtar en relativt liten lokal modell. Hämtningen visar procenttal och slutar normalt med **`success`**. Den är en första funktionskontroll, inte ett löfte om tillräcklig kvalitet för långa arbetsmöten. Vi börjar med den för att begränsa belastningen på din Mac med 16 GB minne.

Kontrollera:

```bash
ollama list
```

**Du ska se:** `qwen2.5:3b` i listan. Om det står att servern inte går att nå, öppna Ollama igen. Om hämtningen inte lyckas, skicka feltexten.

Du behöver inte köra `ollama run`. Det skulle starta en separat chatt. Appen kommer själv att be modellen arbeta när du väljer Summarize.

## 10. Skapa en helt separat Obsidian-testvault

En vault är bara en mapp. Vi använder inte din vanliga vault under första testet.

Kör:

```bash
mkdir -p "$HOME/MeetingTranscriber-testvault"
open "$HOME/MeetingTranscriber-testvault"
```

Finder öppnar testmappen. Den ligger direkt i din användarmapp och heter **MeetingTranscriber-testvault**.

I **Obsidian**:

1. Öppna valet för att hantera/öppna vaults. Om du redan använder Obsidian finns vault-väljaren normalt längst ned i vänsterspalten.
2. Välj **Open folder as vault** / öppna en mapp som vault, och klicka **Open**.
3. Välj **MeetingTranscriber-testvault** i din användarmapp.
4. Om Obsidian frågar om du litar på mappen kan du godkänna just denna nyskapade testmapp. Inga extra plugins behövs.
5. Skapa en ny anteckning med namnet **Testtaggar**. Skriv följande i den:

```text
Detta är en separat testvault.
Befintlig tagg för testet: #architecture
```

Vi skapar taggen i förväg eftersom appen bara ska använda taggar som redan finns i vaulten.

## 11. Ställ in Obsidian och Ollama i appen

Öppna appens **Settings... → Output**. Rulla ned om du inte ser alla fält.

Ställ in följande:

| Fält eller knapp | Ditt val |
| --- | --- |
| Summary execution | **Manual after transcript** |
| Choose vault… | Välj **MeetingTranscriber-testvault** som hel mapp. Välj inte en undermapp. |
| Archive retention | Låt **180 days** stå kvar. |
| LLM Provider | Välj **OpenAI-Compatible API**. |
| Endpoint | Skriv exakt **`http://localhost:11434/v1`**. |
| API Key | Lämna tomt för den lokala Ollama-servern. |

Klicka **Fetch Models** eller **Refresh Models**. Du ska få en grön anslutningsindikering. Välj sedan **`qwen2.5:3b`** i fältet **Model**. Om fältet är en textruta, skriv exakt samma namn där.

`localhost` betyder din egen Mac. OpenAI-kompatibel är namnet på anslutningsformatet; med adressen ovan går sammanfattningsförfrågan till lokala Ollama. Du behöver ingen OpenAI-nyckel eller molntjänst för detta test. Använd inte en annan adress eller godkänn fjärröverföring för att försöka åtgärda ett lokalt anslutningsfel.

Klicka **Open meeting-summary prompt**. Detta skapar den förvalda svenska instruktionstexten i testvaulten om den inte redan finns. Ändra den inte under första testet. Kontrollera i Obsidian eller Finder att filen finns under:

```text
AI/System/Prompts/Meeting-Summary.md
```

En befintlig fil ska lämnas kvar. Att några äldre reglage om råtext är grå när vaulten är vald är väntat; det nya vaultflödet sköter dessa filer.

## 12. Testa textimport och manuell sammanfattning

Vi använder en helt påhittad mötestext. Du behöver ännu inte konfigurera WhisperKit eller mikrofonen.

### 12A. Skapa testtexten

Kopiera hela denna ruta till Terminal. Den skapar filen **MeetingTranscriber-testmote.txt** på skrivbordet. Om du kör rutan igen ersätter den just denna testfil.

```bash
cat > "$HOME/Desktop/MeetingTranscriber-testmote.txt" <<'TESTMOTE'
Detta är ett påhittat testmöte den 8 oktober 2026 klockan 10:15.
Mötestitel: Arkitektur för testprojektet.

[Anna] Målet är att få en första fungerande testversion den 20 oktober 2026.
[Johan] Vi har beslutat att börja med lokal lagring och skjuta på molnsynk.
[Anna] Det beslutet gäller bara testprojektet. Ingen produktionslösning ändras.
[Johan] Jag ansvarar för checklistan. Den ska vara klar den 15 oktober.
[Anna] Lena ansvarar för att kontrollera leverantörens besked senast den 16 oktober.
[Johan] Risken är att leverantörens besked kommer för sent. Då kan datumet för testversionen behöva ändras.
[Anna] Det är ännu inte beslutat om vi ska lägga till en mobilapp.
[Johan] Nästa avstämning är den 19 oktober klockan 09:00.
[Anna] Det här hör till vårt område architecture.
TESTMOTE
```

Öppna gärna filen i Finder och kontrollera att den innehåller texten ovan.

### 12B. Importera texten

1. Klicka på Meeting Transcribers menyradsikon.
2. Öppna **Pending summaries (0)**. Siffran kan vara en annan om du redan provat.
3. Välj **Import / reprocess transcript…**.
4. Välj **MeetingTranscriber-testmote.txt** på skrivbordet och öppna den.
5. Öppna Pending-menyn igen. Om listan inte ändrats, välj **Refresh** där.

**Du ska se:** ett nytt Pending-objekt märkt **Date needed**. Ingen sammanfattning ska skapas automatiskt, eftersom vi valde manuellt läge. Källfilen på skrivbordet ska finnas kvar.

I Finder kan du nu öppna:

```bash
open "$HOME/MeetingTranscriber-testvault/AI/Transcriptions/Pending"
```

Det ska finnas en `.txt`-fil och en `.json`-fil med långa identitetsnamn. `.txt` är texten; `.json` innehåller uppgifter som datum och status. Du behöver inte öppna eller ändra JSON-filen.

### 12C. Ange testmötets datum

I Pending-menyn öppnar du undermenyn för den importerade texten och väljer **Set meeting date/time…**. Ange **8 oktober 2026, klockan 10:15** och klicka **Save**.

Det är det påhittade mötets datum. Vi väljer det uttryckligen för att kunna kontrollera att anteckningen dateras efter mötet, även om du kör modellen en annan dag. Vid framtida egna importer använder du det riktiga mötesdatumet.

Menytexten ska nu visa **2026-10-08** i stället för Date needed. Du kan även slå på **Keep raw transcript indefinitely** för just detta testobjekt; det undantar texten från senare gallring.

### 12D. Begär sammanfattningen

Välj **Summarize / Retry** för objektet. Vänta tills jobbet är klart. Första körningen kan ta extra tid när modellen läses in. Menyn kan visa **Summarizing…**.

**Godkänt:** objektet försvinner ur Pending, du får en färdig mötesanteckning och **Open latest Obsidian note** visas i menyn. Klicka på det, eller öppna anteckningen från Obsidian.

Anteckningen ska ligga i:

```text
AI/Meeting notes/2026/2026-10-08 - <en mötestitel>.md
```

Titeln efter datumet kan variera mellan körningar. Den råa texten ska nu finnas i:

```text
AI/Transcriptions/Archive/2026/
```

Kontrollera innehållet, inte bara att filen skapades:

- Anteckningen är på svenska.
- Testversionens mål är 20 oktober; checklistan har Johan som ansvarig och 15 oktober som datum.
- Lena ska kontrollera leverantörens besked senast 16 oktober.
- Risken om sent besked finns med.
- Mobilappen beskrivs som en öppen fråga, inte ett fattat beslut.
- Nästa avstämning är 19 oktober klockan 09:00.
- Datumet är **2026-10-08**, även om du testar en annan dag.
- Eventuella taggar är bara de som redan fanns, exempelvis `architecture`. Att modellen väljer inga taggar kan också vara korrekt; den ska inte hitta på nya.

Längst upp i Markdown-filen ligger egenskaperna **noteType, date, customer, members, tags** i den ordningen. Obsidian kan visa dem som ett egenskapsformulär. För att se textformen, öppna filen i Textredigerare via Finder: högerklicka → **Öppna med → Textredigerare**. `customer` och `members` är för närvarande tomma i den kodskapade egenskapsdelen; det är inte bevis på att importen misslyckats.

Om en viktig uppgift saknas eller ändrats är innehållstestet underkänt även om appen säger att sammanfattningen är klar. Spara testanteckningen och berätta vad som blev fel.

### 12E. Kontrollera att råtexten är oförändrad

Vi jämför källfilen med den arkiverade texten exakt, även sådant som radbrytningar.

Kopiera hela rutan till Terminal. Ett vanligt Mac-fönster för filval öppnas:

```bash
MT_TEST_ARCHIVE="$(osascript -e 'POSIX path of (choose file with prompt "Välj den arkiverade .txt-filen i testvaultens Archive/2026")')"
if [ -n "$MT_TEST_ARCHIVE" ]; then
    cmp "$HOME/Desktop/MeetingTranscriber-testmote.txt" "$MT_TEST_ARCHIVE"
    echo "Jämförelsens resultatkod: $?"
fi
```

I filfönstret trycker du **⌘⇧G** (Command + Shift + G) och klistrar in:

```text
~/MeetingTranscriber-testvault/AI/Transcriptions/Archive/2026
```

Tryck Retur, markera den arkiverade **`.txt`-filen** och klicka Öppna. Välj inte JSON-filen eller mötesanteckningen. Vid första testet ska bara en arkiverad text finnas; om flera finns, välj den senaste som hör till testtexten.

**Godkänt:** `Jämförelsens resultatkod: 0`. Kommandot `cmp` är tyst när filerna är identiska, vilket är normalt. Annan kod eller en rad om skillnader betyder att du ska rapportera resultatet. Om du avbryter filvalet utförs ingen jämförelse; det är inte ett godkänt test.

## 13. Testa att ett fel inte tappar bort texten

Vi gör anslutningen fel med avsikt, utan att ändra din riktiga data.

1. Importera testtexten igen och ange samma påhittade mötesdatum.
2. Kontrollera att ett nytt objekt finns i Pending.
3. Gå till **Settings → Output → Endpoint** och ändra till **`http://localhost:11435/v1`**. Det är en annan lokal port där vi inte förväntar oss en Ollama-server. Om du själv har en server där, hoppa över detta test och berätta det.
4. Välj **Summarize / Retry** för det nya objektet.
5. Vänta på felmeddelandet. **Godkänt för detta feltest:** objektet ligger kvar i Pending och råtexten är kvar. Ett felmeddelande är nu det vi försöker framkalla.
6. Ändra Endpoint tillbaka till **`http://localhost:11434/v1`**. Kontrollera att **Model** fortfarande är `qwen2.5:3b`.
7. Klicka **Fetch Models / Refresh Models** och kontrollera anslutningen.
8. Välj **Summarize / Retry** igen. Nu ska jobbet kunna bli klart.
9. Kontrollera att din första anteckning fortfarande finns. En ny anteckning får ett eget namn; om namnet krockar kan det få ett siffertillägg.

Lämna inte feladressen kvar efter testet. Om modellen i stället svarar men inte följer instruktionerna kan sammanfattningen också nekas; råtexten ska då fortfarande vara kvar i Pending.

## 14. Testa flera väntande texter

1. Importera testtexten två gånger. Varje import blir ett eget objekt.
2. Ange mötesdatum för båda.
3. Begär sammanfattning för det första, och därefter för det andra medan första fortfarande arbetar.
4. Försök begära det första igen. Menyvalet kan vara avstängt under arbetet; dubbla klick ska inte skapa extra jobb.
5. Vänta tills båda har blivit klara.

**Godkänt:** båda texterna behandlas, resultatet blir två nya anteckningar och tidigare filer finns kvar. Medan första arbetar väntar det andra. De automatiska kötesterna kontrollerar dessutom att modellen anropas för högst ett jobb åt gången; enbart menyn är inte en exakt mätning av detta.

När steg 12–14 fungerar har du testat text- och sammanfattningsflödet. Inspelning, kalender och stora modeller är separata tester nedan.

## 15. Testa inspelning först när textflödet fungerar

Använd ett kort separat testmöte och personer som vet att ni provar inspelning. Behåll testvaulten som mål. Börja med 1–2 minuter och påhittade projektuppgifter.

### Förbered ljudmodellen och språket

Öppna **Settings → Transcription**:

1. Välj **WhisperKit (Whisper)** under **Engine**.
2. Klicka **Refresh available WhisperKit models**.
3. Välj den fulla **Large V3**-varianten om den finns. **Large V3 Turbo är en annan variant.** Ett tekniskt modellnamn kan visas i stället för den korta etiketten; anteckna namnet du valt. Om full Large V3 saknas eller inte kan hämtas, rapportera det i stället för att anta att Turbo är samma sak.
4. Välj **Swedish** under **Language** för det svenska testmötet. Detta styr tal-till-text och är separat från sammanfattningens språk.
5. Klicka **Load Model** om knappen visas. Vänta på **Model ready**. Hämtning och första inläsning kan ta tid och flera GB lagring.
6. Låt **Enable live transcription during recording** vara av i första testet. Det är ytterligare en funktion och kan hämta andra modeller.

Om datorn får minnesproblem med full Large V3 kan vi göra ett separat test med en mindre variant. Det ska vara ett medvetet val, inte en osynlig ersättning. Sammanfattningsmodellen och ljudmodellen konkurrerar om samma 16 GB minne. Manual-läget är valt för att undvika samtidig automatisk sammanfattning under inspelningen.

### Kontrollera Macens tillstånd

I **Systeminställningar → Integritet och säkerhet** kontrollerar du mikrofon och kategorin för skärm-/systemljudinspelning. Namnet varierar mellan macOS-versioner. Ge tillstånd till det här utvecklingsbygget när det efterfrågas. I **Systeminställningar → Notiser** tillåter du synliga notiser för appen. Fokus/Stör ej kan påverka visningen.

I appens **Settings → Audio** ska **No Microphone (app audio only)** vara av om din egen röst ska följa med. Välj mikrofonen du verkligen använder. Appen kan behöva avslutas via **Quit** och startas igen efter ett ändrat Mac-tillstånd.

### Prova Ignore

1. Kontrollera **Ask before recording**, **Microsoft Teams på** och **Manual after transcript**.
2. Klicka **Start Watching** i appens meny.
3. Gå in i ett separat Teams-testmöte med mikrofonen aktiv.
4. Vänta på frågan om inspelning. Om notisen inte syns, öppna appens meny och leta efter **Record meeting in …?**, **Record** och **Ignore**.
5. Välj **Ignore**. Appen ska inte spela in detta möte och ska inte fråga om och om igen under samma pågående möte.
6. Lämna mötet helt. Vänta en stund så att appen hinner upptäcka att det avslutats.

### Prova Record i ett nytt möte

1. Starta ett nytt testmöte. Frågan ska kunna komma igen.
2. Välj **Record**.
3. Säg några tydliga meningar. Om en annan person deltar, låt den också prata så att vi kan kontrollera båda sidor av ljudet.
4. Lämna mötet och vänta på att appen avslutar inspelningen och behandlar ljudet. Det kan finnas en kort väntetid innan inspelningen stoppas.
5. Om du får en dialog för att namnge talare, bekräfta namnen eller välj dess möjlighet att hoppa över. En väntande namndialog måste hanteras innan du kan förvänta dig färdig Pending-text.
6. Kontrollera att texten hamnar i Pending utan att en sammanfattning skapas automatiskt.
7. Kontrollera att det du och den andra personen sa finns i texten. Begär sedan sammanfattning manuellt som i steg 12.

**Godkänt:** Ignore ger ingen inspelning; Record gör det; texten innehåller båda rösterna om båda deltog; sammanfattningen väntar på din begäran. Du ska kunna avsluta ett möte med text kvar i Pending och senare använda appen för ett nytt möte.

Om frågan inte kommer eller ljudet är tyst, rapportera det. Välj inte automatisk inspelning för att kringgå ett misslyckat samtyckestest.

## 16. Testa kalenderkopplingen separat

Det här steget är valfritt för det första försöket. Inspelning och text ska fungera även utan kalenderåtkomst.

1. Öppna Apples **Kalender**-app. Kontrollera att den kalender du vill använda syns där och visar sina möten. Att kalendern bara finns i Outlook räcker inte för EventKit-kopplingen.
2. Om arbetskalendern inte syns i Apples Kalender, rapportera det. Ändra inte ditt företags kontokonfiguration på chans; den kan behöva hjälp från IT.
3. Skapa ett separat testmöte i en lämplig testkalender, med titel **Kalendertest** och tid som överlappar det kommande inspelningstestet. Använd inte ett heldagsevent. Inga privata deltagaruppgifter behövs för detta första försök.
4. I appens **Settings → General**, slå på **Use selected calendars**.
5. Klicka **Allow calendar access / Refresh**. Godkänn tillståndet i macOS-dialogen om du vill genomföra detta test. Systemdialogen kan beskriva bredare kalenderåtkomst än de fält vår kod faktiskt läser.
6. Markera bara den testkalender du avser att använda. Lämna andra kalendrar omarkerade.
7. Gör ett kort inspelningstest vid den angivna tiden. Kalenderuppgifter kan ge extra sammanhang; kalendern startar aldrig en inspelning åt dig.

Ett otydligt fall med flera lika möjliga event ska lämnas utan kalenderkoppling. Appen söker inte i eventets beskrivning efter Teams-länkar, så en länk som bara finns i beskrivningen är ingen garanti för matchning. Saknad metadata i ett sådant fall betyder inte i sig att inspelningen misslyckats.

Om du vill prova nekat tillstånd kan du stänga av kalenderåtkomst för appen i Systeminställningar och göra ett nytt test. Inspelning och transkribering ska fortsätta fungera. Slå sedan av **Use selected calendars** eller återställ tillståndet för fortsatta kalenderförsök.

## 17. Ytterligare kodkontroll — kan tas efter första lyckade testet

Det finns två extra kontrollverktyg, **SwiftFormat** och **SwiftLint**, som granskar kodens format och regler. De behövs inte för att klicka runt i appen, men kontrollen återstår innan vi kan bedöma utkastet som färdigt. Vi använder projektets bestämda versioner för att resultatet ska gå att jämföra.

Kör detta i projektets Terminal-fönster:

```bash
mkdir -p "$HOME/Library/Caches/MeetingTranscriber-lint-tools"
export RUNNER_TEMP="$HOME/Library/Caches/MeetingTranscriber-lint-tools"
export GITHUB_PATH="$RUNNER_TEMP/path-list.txt"
bash scripts/ci/install-lint-tool.sh swiftformat
```

**Du ska se:** att kontrollsumman stämmer och att `swiftformat` installerats. Om det misslyckas, stanna. Fortsätt annars:

```bash
bash scripts/ci/install-lint-tool.sh swiftlint
```

**Du ska se:** motsvarande lyckad installation av `swiftlint`. Kör sedan:

```bash
export PATH="$RUNNER_TEMP/swiftformat-bin:$RUNNER_TEMP/swiftlint-bin:$PATH"
bash scripts/ci/install-lint-tool.sh swiftformat --verify
bash scripts/ci/install-lint-tool.sh swiftlint --verify
```

Båda verifieringarna ska visa rätt version utan fel. Kör därefter:

```bash
./scripts/lint.sh > "$HOME/Desktop/MeetingTranscriber-kodkontroll.log" 2>&1
echo "Kodkontrollens resultatkod: $?"
open -a TextEdit "$HOME/Desktop/MeetingTranscriber-kodkontroll.log"
```

**Godkänt:** resultatkod 0. **Vid fel:** skicka loggfilen. Kör inte `--fix`; vi vill se originalfelen och åtgärda dem i koden tillsammans. Dessa verktyg väljs för det nuvarande Terminal-fönstret. Om du öppnar ett nytt fönster behöver sökvägen väljas igen; ett `command not found` i ett nytt fönster betyder inte att själva appen gått sönder.

## När du kan kalla första testet lyckat

För det första texttestet ska du ha:

- Resultatkod 0 för kärntester, Mac-tester och appbygge.
- En startbar app med rätt inställningar.
- Import som bevarar källtexten och väntar på ditt manuella kommando.
- En korrekt svensk anteckning daterad efter testmötet.
- Råtext som flyttas till Archive efter anteckningen.
- Ett medvetet anslutningsfel som bevarar Pending, och en lyckad Retry efter återställning.

Inspelning, kalender, full Large V3, långmöteskvalitet och den extra kodkontrollen får egna resultat. **Ett lyckat kort texttest innebär inte att alla dessa saker redan är godkända.**

Den aktuella sammanfattningen skickar en hel mötestext i en enda förfrågan till den lokala modellen. Långa möten kan överstiga modellens inställda textkapacitet. Börja inte använda riktiga långa möten enbart för att korttestet fungerade; vi behöver kontrollera att innehållet täcks och inte kapas. Det finns ännu ingen automatisk uppdelning av långa transkript.

Testa inte 180-dagarsgallringen genom att ändra datum, flytta metadata eller välja din riktiga vault. Den grundläggande gallringslogiken har automatiska tester. Om vi vill göra ett separat Mac-test av gallring tar vi fram en särskild testuppsättning.

## Vad du skickar till mig när något går fel

Du behöver inte tolka felet. Skicka:

1. **Stegnummer:** exempelvis “steg 7, appbygge”.
2. **Vad du gjorde:** vilket kommando eller vilket menyval.
3. **Vad du såg:** resultatkod, exakt feltext eller en skärmbild.
4. **Relevant loggfil:** filerna heter `MeetingTranscriber-…log` och ligger på skrivbordet.
5. **Mac-information:** macOS-version och utskriften från `xcodebuild -version` och `swift --version`.

För sammanfattningsproblem är den påhittade texten och den genererade testanteckningen användbara. För ett riktigt arbetsmöte: skicka inte hela mötestexten eller deltagaruppgifter för att rapportera ett tekniskt problem. Berätta först vilket steg som gick fel, så väljer vi lämplig information.

Du kan kopiera den här mallen:

```text
Steg:
Jag gjorde:
Jag förväntade mig:
Jag såg / resultatkod:
macOS-version:
Xcode-version:
Swift-version:
Bifogad testlogg eller bild:
```

Vanliga stopp och första åtgärden:

| Det du ser | Vad du gör |
| --- | --- |
| `No such file or directory` när du använder `cd` | Öppna projektet genom GitHub Desktops Repository → Open in Terminal. |
| Fel branch | Välj `codex/obsidian-meeting-workflow` i GitHub Desktop. |
| Xcode/Swift för gammal | Stanna och skicka versionsuppgifterna. |
| `command not found: ollama` | Öppna Ollama, kontrollera dess kommandoinstallation och prova ett nytt Terminal-fönster. |
| Modellen saknas | Kontrollera `ollama list`; det exakta namnet ska vara `qwen2.5:3b`. |
| Grå Obsidian-inställningar | Kontrollera att Record-only mode är av. |
| `Date needed` eller avstängd Summarize-knapp | Ange mötets datum/tid i Pending-undermenyn. |
| Ingen notisfråga | Kontrollera menyradens Record/Ignore och Macens notisinställningar. |
| Ingen kalender i listan | Kontrollera om den över huvud taget syns i Apples Kalender. |
| Tyst eller ofullständig inspelning | Stoppa testet och rapportera mikrofonval, tillstånd och vad som saknas. |
| Sammanfattning misslyckas | Behåll Pending. Kontrollera adress/modell och skicka feltexten; radera inte råtexten. |
| Appen syns inte som ett stort fönster | Leta efter menyradsikonen; det är där appen används. |

## Avsluta och starta nästa gång

Avsluta Meeting Transcriber via **Quit** i dess menyradsmeny. Det ska normalt lämna färdiga Pending-texter på disk så att de kan visas nästa gång. Undvik att avsluta mitt i första lyckade testet innan du har kontrollerat resultatet.

Nästa gång behöver du inte hämta modeller eller bygga igen om koden är densamma. Öppna Ollama och starta appen från Terminal:

```bash
cd "$HOME/Documents/GitHub/meeting-transcriber"
open "app/MeetingTranscriber/.build/MeetingTranscriber-Dev.app"
```

Om vi uppdaterar koden i branchen: avsluta appen, hämta uppdateringen med GitHub Desktop och upprepa testerna och bygget från steg 5–7. Starta sedan den nybyggda appen. Om Desktop varnar för lokala ändringar, stanna i stället för att kasta dem.

När du är klar för dagen behöver du inte ta bort koden, testvaulten eller modellerna. De kan ligga kvar inför nästa test. Ingen merge till `main`, release eller kontakt med ursprungsprojektet ingår i denna guide.
