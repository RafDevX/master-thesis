I takt med att dagens samhälle blir alltmer beroende av digitala system,
blir informationens ursprung allt viktigare, även utöver de konkreta uppgifter
det är förknippat med. Sådan proveniensmetadata spelar i synnerhet en viktig
roll inom cybersäkerhet, eftersom den ofta avgör var och hur information kan
användas: hemliga indata bör inte vara offentligt observerbara, medan opålitliga
indata behöver i regel saneras innan de når kritiska delar.

// "taintanalys" is not real Swedish, but FOI translates it as
// "dataflödesanalys av potentiellt osäkra data", which is too long
// https://www.foi.se/rest-api/report/FOI-R--5790--SE
Detta arbete använder tekniker för informationsflödeskontroll för att modellera
en flexibel statisk taintanalys, med fokus på att upptäcka olika former av
konfidentialitets- och integritetsbrister. Analysen är starkt specialiserad och
särskilt utformad för programspråket Go, med tonvikt på en sund och precis
hantering av många konstruktioner och funktioner i Go, inom en avgränsad
delmängd av språket och med vissa undantag och approximationer.

Analysen kan generellt tillämpas på en betydande andel av Go-program. Den är
källkodsbaserad, medför inga körtidskostnader och är interprocedurell,
anropsplatskänslig samt delvis flödeskänslig. Go-moduler utgör dess
grundläggande enhet, och samtliga möjliga kombinationer av
byggtaggsbegränsningar undersöks oberoende av varandra.

De huvudsakliga bidragen från detta examensarbete är Glowy, som omfattar såväl
den teoretiska modellen för statisk taintanalys av Go som en motsvarande
implementation i Rust på cirka $35" "000$ rader kod, samt en korpus med $230$
moduler som används för korrekthetsutvärdering och för att illustrera möjliga
informationsflöden i Go. Därtill presenteras en omfattande utvärdering baserad
på en granskning av $371$ Go-moduler hämtade från $300$ populära projekt med
öppen källkod. Granskningen identifierade verkliga säkerhetsbrister som påverkar
både konfidentialitet och integritet, däribland läckage av
inloggningsuppgifter och _Server-Side Request Forgery_-sårbarheter.

Särskild vikt läggs vid avvägningen mellan sundhet och precision,
samtidigt som användbarhet, effektivitet och flexibilitet ges hög prioritet.
Detta uppnås bland annat genom ett nytt valbart axlarsystem som möjliggör
komplexa användningsfall utan att göra avkall på enkelheten.

Sammantaget visar resultaten att statisk taintanalys av Go, baserad på
uttrycksfulla säkerhetskontroller, har potential att bidra till faktisk
säkerhet.
