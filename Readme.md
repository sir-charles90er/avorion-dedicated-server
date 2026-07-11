AVORION DEDICATED SERVER – DOCKER-KONFIGURATION
================================================

Stand: 10.07.2026

Container starten: docker compose up -d

Constainer stoppen: docker compose stop avorion

nach einem docker "compose stop avorion" funktioniert auch: docker compose start avorion


Nach dem erstmaligen Ausführen ist die server.ini in "avorion-dedicated-server/data/galaxies/avorion_galaxy/server.ini" zu finden. 
Um bestimmte Parameter (z. B. building knowledge) ändern zu können, muss "scenario=3" (free play) gesetzt werden. 
Hier können auch Worker-Threads, server-passwort etc. konfiguriert werden. 
Die Empfehlungen für Threads aus dem Avorion-Wiki (https://avorion.fandom.com/wiki/Setting_up_a_server) lauten wie folgt: 
  - Worker Threads entsprechend hardware-concurrency (z. B. 6 physische Kerne ohne Hyperthreading --> 6 worker threads)
  - mindestens 2 Generator Threads, aber nicht mehr als hardware-concurrency
  - 1/4 bis 1/2 der generators threads als Script Background Threads

Die beigefügte server.ini.example konfiguriert einen eigenen seed, ein eigenes Passwort und deaktiviert Building Knowledge sowie alle Begrenzungen der Schiffsgröße. 



Diese Datei erklärt alle Parameter der mitgelieferten .env-Datei sowie die
verfügbaren Kommandozeilenargumente für EXTRA_SERVER_ARGS.

WICHTIG:
- Die Datei .env enthält mindestens die persönliche SteamID64 des Administrators.
  Sie sollte nicht veröffentlicht oder in ein öffentliches Git-Repository
  eingecheckt werden.
- Empfohlene Dateirechte auf dem Ubuntu-Host:

    chmod 600 .env

- Nach Änderungen an .env muss der Container neu erstellt beziehungsweise neu
  gestartet werden:

    docker compose up -d --force-recreate

- Serverprotokoll anzeigen:

    docker compose logs -f avorion

- Sauber stoppen:

    docker compose stop

  Das Entrypoint-Skript sendet zuerst /save, wartet die konfigurierte Zeit und
  sendet anschließend /stop.


1. AUFBAU EINER .env-ZEILE
==========================

Eine Variable wird grundsätzlich so gesetzt:

    NAME=Wert

Leerzeichen nach dem Gleichheitszeichen gehören zum Wert. Kommentare beginnen
mit #. Bei normalen Werten sind keine Anführungszeichen erforderlich.

Beispiel:

    SERVER_NAME=Mein Avorion Server

Bei EXTRA_SERVER_ARGS darf die gesamte Argumentfolge optional in einfache oder
doppelte Anführungszeichen gesetzt werden. Werte einzelner Argumente dürfen in
der aktuellen entrypoint.sh jedoch keine Leerzeichen enthalten, weil die
Argumentfolge nur anhand von Leerzeichen aufgeteilt wird.

Geeignet:

    EXTRA_SERVER_ARGS=--seed TestGalaxy123 --collision-damage 0.5

Nicht geeignet:

    EXTRA_SERVER_ARGS=--seed "Mein Seed"

Die inneren Anführungszeichen werden von entrypoint.sh nicht als Gruppierung
ausgewertet.


2. DATEIRECHTE UND CONTAINER-BENUTZER
=====================================

PUID
----
Benutzer-ID, unter der der Avorion-Server innerhalb des Containers läuft.

Standard:

    PUID=1000

Auf einem typischen Ubuntu-System besitzt der zuerst angelegte normale Benutzer
die UID 1000. Die korrekte UID des aktuellen Benutzers kann so ermittelt werden:

    id -u

Der Wert muss eine positive Ganzzahl sein. UID 0, also root, wird vom
Entrypoint-Skript abgelehnt.

PUID sollte zur Eigentümer-UID der persistenten Host-Verzeichnisse passen:

    ./data/server
    ./data/galaxies


PGID
----
Gruppen-ID, unter der der Avorion-Server innerhalb des Containers läuft.

Standard:

    PGID=1000

Die korrekte primäre GID des aktuellen Benutzers kann so ermittelt werden:

    id -g

Der Wert muss eine positive Ganzzahl sein. GID 0 wird abgelehnt.

Nach einer Änderung von PUID oder PGID kann es erforderlich sein, die
Besitzrechte der Datenverzeichnisse auf dem Host zu korrigieren:

    sudo chown -R "$(id -u):$(id -g)" ./data


3. ADMINISTRATOR
================

ADMIN_STEAM_ID
--------------
SteamID64 des anfänglichen Serveradministrators.

Beispiel:

    ADMIN_STEAM_ID=76561198000000000

Der Platzhalter muss ersetzt werden. Zulässig ist ausschließlich eine numerische
SteamID64 mit 16 bis 20 Ziffern. Es handelt sich nicht um den Steam-Namen, die
Profil-URL, die SteamID im Format STEAM_0:X:Y oder Anmeldedaten.

Keine Steam-E-Mail-Adresse und kein Steam-Passwort eintragen. SteamCMD verwendet
für diesen Dedicated Server eine anonyme Anmeldung.

Die Variable ist verpflichtend. Ohne gültigen Wert beendet sich der Container
mit einer Fehlermeldung.


4. GALAXIE UND SERVER
=====================

GALAXY_NAME
-----------
Name der Galaxie und gleichzeitig Name ihres Unterverzeichnisses im persistenten
Galaxie-Datenpfad.

Standard:

    GALAXY_NAME=avorion_galaxy

Zulässige Zeichen in dieser Konfiguration:

    A-Z  a-z  0-9  Punkt  Unterstrich  Bindestrich

Leerzeichen, Umlaute, Schrägstriche und andere Sonderzeichen werden vom
Entrypoint-Skript abgelehnt.

Die Galaxiedaten befinden sich auf dem Host anschließend unter:

    ./data/galaxies/<GALAXY_NAME>/

Eine Änderung des Namens erzeugt beziehungsweise verwendet eine andere Galaxie.
Sie benennt eine bestehende Galaxie nicht automatisch um.


SERVER_NAME
-----------
Anzeigename des Servers in der Serverliste.

Standard:

    SERVER_NAME=Mein Avorion Server

Leerzeichen sind erlaubt. Der Wert wird als ein einzelnes Argument an Avorion
übergeben.


SERVER_PORT
-----------
Hauptport des Avorion-Servers.

Standard:

    SERVER_PORT=27000

Gültiger Bereich:

    1 bis 65535

compose.yaml veröffentlicht diesen Port sowohl per TCP als auch per UDP. Bei
einer Änderung wird die Portfreigabe für diesen Hauptport automatisch angepasst.
Die weiteren Avorion-UDP-Ports 27003, 27020 und 27021 bleiben in compose.yaml
fest eingetragen.

Der gewählte Port muss auf dem Ubuntu-Host, in einer eventuell vorgeschalteten
Cloud-Firewall und gegebenenfalls im Router freigegeben sein.

Beispiel für UFW mit dem Standardport:

    sudo ufw allow 27000/tcp
    sudo ufw allow 27000/udp
    sudo ufw allow 27003/udp
    sudo ufw allow 27020/udp
    sudo ufw allow 27021/udp


MAX_PLAYERS
-----------
Maximale Anzahl gleichzeitig verbundener Spieler.

Standard:

    MAX_PLAYERS=10

Der Wert muss eine nichtnegative Ganzzahl sein. Für einen normalen Spielserver
sollte mindestens 1 verwendet werden. Eine höhere Spielerzahl erhöht in der
Regel CPU-, Arbeitsspeicher-, Netzwerk- und Datenträgerlast.


SAVE_INTERVAL
-------------
Zeitabstand zwischen automatischen Speicherungen in Sekunden.

Standard:

    SAVE_INTERVAL=300

Das entspricht fünf Minuten. Der Wert muss eine nichtnegative Ganzzahl sein.
Sehr kurze Intervalle erhöhen die Schreiblast. Ein zu großes Intervall vergrößert
den möglichen Fortschrittsverlust bei einem Absturz oder harten Host-Ausfall.

Das geordnete Beenden des Containers verwendet unabhängig davon zusätzlich den
Konsolenbefehl /save.


DIFFICULTY
----------
Schwierigkeitsgrad der Galaxie.

Standard:

    DIFFICULTY=0

Zulässige Werte:

    -3 = Beginner
    -2 = Easy
    -1 = Normal
     0 = Veteran
     1 = Expert
     2 = Hardcore
     3 = Insane

Das Entrypoint-Skript akzeptiert nur Werte von -3 bis 3.

Vorsicht bei Hardcore und Insane: Diese Stufen verwenden permanente Zerstörung.
Änderungen des Schwierigkeitsgrades einer bereits existierenden Galaxie können
zusätzlichen Regeln des Spiels unterliegen.


SERVER_THREADS
--------------
Anzahl der Worker-Threads, die Avorion für die Aktualisierung von Sektoren
verwendet.

Standard:

    SERVER_THREADS=

Ein leerer Wert bedeutet, dass entrypoint.sh kein --threads-Argument übergibt.
Avorion verwendet dann seine eigene Vorgabe beziehungsweise den Wert aus der
server.ini.

Beispiel:

    SERVER_THREADS=8

Bei gesetztem Wert ist mindestens 1 erforderlich. Eine unnötig hohe Zahl kann
Leistung verschlechtern. Avorion besitzt zusätzlich Generator-Threads und
Script-Background-Threads; diese werden nicht über SERVER_THREADS konfiguriert,
sondern normalerweise in der server.ini der Galaxie.


PUBLIC
------
Legt fest, ob andere Spieler dem Server beitreten dürfen.

Standard:

    PUBLIC=1

Werte in dieser Konfiguration:

    1 = aktiviert
    0 = deaktiviert

Der Wert wird als --public an Avorion übergeben.


LISTED
------
Legt fest, ob der Server in öffentlichen Serverlisten erscheinen soll.

Standard:

    LISTED=1

Werte:

    1 = in öffentlichen Listen anzeigen
    0 = nicht öffentlich auflisten

Für eine öffentliche Steam-Listung müssen zusätzlich die Netzwerk- und
Authentifizierungseinstellungen des Servers passen.


USE_STEAM_NETWORKING
--------------------
Aktiviert Steam Networking und Steam-Authentifizierung für Spieler.

Standard:

    USE_STEAM_NETWORKING=1

Werte:

    1 = aktiviert
    0 = deaktiviert

Eine Deaktivierung verändert Erreichbarkeit, Authentifizierung und Beitritt über
Steam. Der Standardwert 1 ist für einen üblichen öffentlichen oder privaten
Steam-Spielserver empfohlen.


5. STEAMCMD UND SERVER-UPDATES
=============================

UPDATE_ON_START
---------------
Steuert, ob der Avorion Dedicated Server bei jedem Containerstart über SteamCMD
installiert beziehungsweise aktualisiert wird.

Standard:

    UPDATE_ON_START=true

Als wahr erkennt das Skript:

    1, true, yes, on

Groß- und Kleinschreibung ist dabei unerheblich. Alle anderen Werte gelten als
falsch.

Hinweis: Fehlt /opt/avorion/server.sh, wird die Installation unabhängig von
dieser Einstellung ausgeführt. Dadurch kann ein frisches Datenverzeichnis auch
mit UPDATE_ON_START=false initialisiert werden.

Empfehlung:

    UPDATE_ON_START=true

Dadurch kann der Start länger dauern, wenn Steam ein Update bereitstellt.


VALIDATE_ON_START
-----------------
Steuert, ob SteamCMD beim Installieren oder Aktualisieren zusätzlich die
Serverdateien validiert.

Standard:

    VALIDATE_ON_START=false

Als wahr erkennt das Skript:

    1, true, yes, on

Bei true wird das SteamCMD-Schlüsselwort validate an app_update angehängt.
Die Prüfung kann einen Start deutlich verlängern, ist aber bei beschädigten oder
unvollständigen Serverdateien hilfreich.

Typische Verwendung zur einmaligen Reparatur:

    VALIDATE_ON_START=true

Nach erfolgreicher Prüfung kann der Wert wieder auf false gesetzt werden.


STEAM_BRANCH
------------
Optionaler Steam-Betabranch für den Dedicated Server.

Standard:

    STEAM_BRANCH=

Leer bedeutet den stabilen Standardbranch. Beispiel für einen verfügbaren
öffentlichen Betabranch:

    STEAM_BRANCH=beta

Der Branch muss bei Steam tatsächlich existieren und anonym zugänglich sein.
Beim Wechsel von einem neueren Beta-Stand zurück auf den stabilen Stand kann
eine Galaxie inkompatibel werden. Vor Branchwechseln immer die Galaxiedaten
sichern.

Backup-Beispiel bei gestopptem Server:

    tar -czf "avorion-galaxies-$(date +%F-%H%M%S).tar.gz" ./data/galaxies


6. GEORDNETES HERUNTERFAHREN
============================

SHUTDOWN_SAVE_WAIT
------------------
Wartezeit in Sekunden zwischen dem Konsolenbefehl /save und /stop.

Standard:

    SHUTDOWN_SAVE_WAIT=10

Der Wert muss eine nichtnegative Ganzzahl sein. Die Pause gibt dem Server Zeit,
die Galaxie nach /save auf den Datenträger zu schreiben. Bei großen Galaxien oder
langsamen Datenträgern kann ein höherer Wert sinnvoll sein.


SHUTDOWN_TIMEOUT
----------------
Maximale Wartezeit in Sekunden nach /stop, bevor das Entrypoint-Skript eine
Eskalation einleitet.

Standard:

    SHUTDOWN_TIMEOUT=120

Ablauf beim Containerstopp:

    1. /save senden
    2. SHUTDOWN_SAVE_WAIT Sekunden warten
    3. /stop senden
    4. bis zu SHUTDOWN_TIMEOUT Sekunden auf das Serverende warten
    5. bei Zeitüberschreitung SIGTERM an die Prozessgruppe senden
    6. weitere 15 Sekunden warten
    7. bei weiterhin laufendem Prozess SIGKILL senden

compose.yaml setzt zusätzlich:

    stop_grace_period: 3m

SHUTDOWN_SAVE_WAIT und SHUTDOWN_TIMEOUT sollten zusammen einschließlich einer
kleinen Reserve innerhalb dieser drei Minuten liegen. Mit den Standardwerten
10 + 120 Sekunden ist ausreichend Reserve vorhanden.


7. EXTRA_SERVER_ARGS
====================

EXTRA_SERVER_ARGS enthält optionale Avorion-Kommandozeilenargumente, die nach
den fest konfigurierten Argumenten an server.sh angehängt werden.

Standard:

    EXTRA_SERVER_ARGS=

Mehrere Argumente werden durch Leerzeichen getrennt:

    EXTRA_SERVER_ARGS=--seed Test123 --collision-damage 0.5

Wichtige Einschränkungen der aktuellen entrypoint.sh:

- Die Zeichenkette wird ausschließlich an Leerzeichen aufgeteilt.
- Einzelne Argumentwerte dürfen deshalb keine Leerzeichen enthalten.
- Shell-Erweiterungen, Variablenersetzung, Backslashes und innere
  Anführungszeichen werden nicht wie in einer interaktiven Shell ausgewertet.
- Keine Semikolons, Pipes, Umleitungen oder sonstige Shell-Befehle verwenden.
  Sie werden nicht als Shell-Code ausgeführt und sind keine gültigen
  Avorion-Argumente.


7.1 BEREITS FEST ÜBER .env GESETZTE ARGUMENTE
---------------------------------------------

entrypoint.sh übergibt diese Argumente immer automatisch:

    --galaxy-name       aus GALAXY_NAME
    --admin             aus ADMIN_STEAM_ID
    --datapath          fest aus AVORION_DATA_DIR
    --server-name       aus SERVER_NAME
    --port              aus SERVER_PORT
    --max-players       aus MAX_PLAYERS
    --save-interval     aus SAVE_INTERVAL
    --difficulty        aus DIFFICULTY
    --public            aus PUBLIC
    --listed            aus LISTED
    --use-steam-networking aus USE_STEAM_NETWORKING
    --threads           aus SERVER_THREADS, sofern nicht leer

Diese Optionen sollten nicht nochmals in EXTRA_SERVER_ARGS erscheinen.
Doppelte Optionen können abhängig von der Avorion-Version abgelehnt werden oder
zu schwer nachvollziehbaren Ergebnissen führen. Für diese Werte immer die
dafür vorgesehene .env-Variable ändern.

Ebenfalls nicht über EXTRA_SERVER_ARGS ändern:

    --datapath

Der Datenpfad ist bewusst mit dem persistenten Docker-Volume verbunden. Eine
Änderung kann dazu führen, dass die Galaxie außerhalb des gemounteten Pfads
landet und beim Entfernen des Containers verloren geht.


7.2 SINNVOLLE ZUSÄTZLICHE ARGUMENTE
-----------------------------------

--seed <WERT>
    Legt den Seed für die Galaxiegenerierung fest.

    Beispiel:

        EXTRA_SERVER_ARGS=--seed MeineGalaxy2026

    Der Seed ist hauptsächlich beim erstmaligen Erstellen einer Galaxie
    relevant. Eine nachträgliche Änderung erzeugt eine bestehende Galaxie nicht
    neu. Für maximale Kompatibilität nur Buchstaben und Ziffern verwenden.


--infinite-resources <0|1>
    Aktiviert oder deaktiviert unendliche Ressourcen für alle Spieler.

    Beispiele:

        EXTRA_SERVER_ARGS=--infinite-resources 1
        EXTRA_SERVER_ARGS=--infinite-resources 0

    1 aktiviert den Kreativmodus mit unendlichen Ressourcen, 0 deaktiviert ihn.


--collision-damage <WERT>
    Multiplikator für Kollisionsschaden.

    Üblicher Bereich:

        0.0 bis 1.0

    Beispiele:

        EXTRA_SERVER_ARGS=--collision-damage 0
        EXTRA_SERVER_ARGS=--collision-damage 0.5
        EXTRA_SERVER_ARGS=--collision-damage 1

    0 bedeutet keinen Kollisionsschaden, 0.5 entspricht 50 Prozent und 1 dem
    vollen Kollisionsschaden.


--same-start-sector <0|1>
    Legt fest, ob alle Spieler im selben Startsektor beginnen.

    Beispiele:

        EXTRA_SERVER_ARGS=--same-start-sector 1
        EXTRA_SERVER_ARGS=--same-start-sector 0

    1 verwendet einen gemeinsamen Startsektor. Bei 0 kann für neue Spieler ein
    eigener Startbereich am äußeren Rand erzeugt werden.


--exit-on-last-admin-logout
    Beendet den Server, sobald sich der letzte Administrator abmeldet.

    Beispiel:

        EXTRA_SERVER_ARGS=--exit-on-last-admin-logout

    Für einen dauerhaft laufenden Dedicated Server ist diese Option meistens
    nicht erwünscht. Endet der Avorion-Prozess dadurch, endet auch der Container.
    Wegen restart: unless-stopped kann Docker den Container danach automatisch
    wieder starten. Das kann einen unerwünschten Neustartzyklus verursachen.


--stderr-to-log
    Leitet die Standardfehlerausgabe des Servers von der Konsole in die
    Avorion-Logdatei um.

    Beispiel:

        EXTRA_SERVER_ARGS=--stderr-to-log

    Dadurch können bestimmte Fehlermeldungen in docker compose logs fehlen und
    stattdessen nur in der Serverlogdatei im Galaxieverzeichnis erscheinen.


--stdout-to-log
    Leitet die normale Standardausgabe des Servers von der Konsole in die
    Avorion-Logdatei um.

    Beispiel:

        EXTRA_SERVER_ARGS=--stdout-to-log

    Für Docker ist diese Option normalerweise nicht empfohlen, weil zentrale
    Ausgaben dann nicht mehr über docker compose logs sichtbar sind.


-t <KATEGORIE>
--trace <KATEGORIE>
    Aktiviert detaillierte Trace-Ausgaben für eine Kategorie. -t und --trace
    sind gleichbedeutend. Die Option kann mehrfach angegeben werden.

    Dokumentierte Kategorien:

        network
        scripting
        threading
        io
        database
        input
        error
        warning
        exception
        user
        game
        system
        debug
        sound
        gl
        all

    Beispiele:

        EXTRA_SERVER_ARGS=-t network
        EXTRA_SERVER_ARGS=--trace database
        EXTRA_SERVER_ARGS=-t network -t scripting
        EXTRA_SERVER_ARGS=-t all

    Tracing kann sehr große Logmengen erzeugen und die Serverleistung deutlich
    verschlechtern. Nur zur gezielten Fehlersuche aktivieren und danach wieder
    entfernen.


7.3 TECHNISCH MÖGLICHE, ABER HIER NICHT EMPFOHLENE OPTIONEN
-----------------------------------------------------------

Die folgenden Optionen gehören zur Avorion-Kommandozeile, werden aber bereits
über eigene Variablen oder feste Containerpfade gesetzt:

--port <PORT>
    Stattdessen SERVER_PORT verwenden.

--max-players <ANZAHL>
    Stattdessen MAX_PLAYERS verwenden.

--save-interval <SEKUNDEN>
    Stattdessen SAVE_INTERVAL verwenden.

--server-name <NAME>
    Stattdessen SERVER_NAME verwenden. Über EXTRA_SERVER_ARGS sind Werte mit
    Leerzeichen in der aktuellen Implementierung nicht sicher darstellbar.

--galaxy-name <NAME>
    Stattdessen GALAXY_NAME verwenden.

--datapath <PFAD>
    Nicht überschreiben. Der persistente Pfad ist im Container fest vorgesehen.

--admin <STEAMID64>
    Stattdessen ADMIN_STEAM_ID verwenden.

--difficulty <-3..3>
    Stattdessen DIFFICULTY verwenden.

--threads <ANZAHL>
    Stattdessen SERVER_THREADS verwenden.

--public <0|1>
    Stattdessen PUBLIC verwenden.

--listed <0|1>
    Stattdessen LISTED verwenden.

--use-steam-networking <0|1>
    Stattdessen USE_STEAM_NETWORKING verwenden.


7.4 HILFEOPTION
---------------

--help
    Gibt die vom installierten Avorion-Server unterstützten Argumente aus und
    beendet den Prozess anschließend.

    --help darf nicht dauerhaft in EXTRA_SERVER_ARGS eingetragen werden, weil
    der Server dann nicht startet und der Container wegen der Restart-Policy in
    einen Neustartzyklus geraten kann.

    Die definitive Liste der Optionen der tatsächlich installierten
    Serverversion kann bei bereits installiertem Server so geprüft werden:

        docker compose exec -u avorion avorion /opt/avorion/server.sh --help

    Falls der Container aktuell nicht läuft, kann zuerst normal gestartet und
    der Befehl danach ausgeführt werden.


7.5 KOMBINIERTE BEISPIELE
-------------------------

Gemeinsamer Startsektor, halber Kollisionsschaden und fester Seed:

    EXTRA_SERVER_ARGS=--seed Community2026 --same-start-sector 1 --collision-damage 0.5

Kreativserver ohne Kollisionsschaden:

    EXTRA_SERVER_ARGS=--infinite-resources 1 --collision-damage 0

Temporäre Netzwerkdiagnose:

    EXTRA_SERVER_ARGS=-t network -t warning -t error

Nach abgeschlossener Diagnose sollte EXTRA_SERVER_ARGS wieder geleert werden:

    EXTRA_SERVER_ARGS=


8. EINSTELLUNGEN, DIE NICHT IN EXTRA_SERVER_ARGS GEHÖREN
========================================================

Avorion besitzt zahlreiche weitere Servereinstellungen, zum Beispiel:

- Serverbeschreibung und Passwort
- Blacklist, Whitelist und Zugriffsmodus
- Pausierbarkeit
- RCON-IP, RCON-Port und RCON-Passwort
- Generator-Threads und Script-Background-Threads
- Anzahl aktiver Sektoren pro Spieler
- Schiffs-, Stations-, Block- und Inventarlimits
- PvP-Schaden
- Logout-Unverwundbarkeit
- Wrack-Aufräumzeiten
- Profiling und Crash-Reports

Diese Werte sind keine in der offiziellen Liste dokumentierten allgemeinen
Kommandozeilenargumente. Sie werden normalerweise in der server.ini innerhalb
des Galaxieverzeichnisses konfiguriert:

    ./data/galaxies/<GALAXY_NAME>/server.ini

WICHTIG:
Die server.ini nur bei vollständig gestopptem Avorion-Server bearbeiten. Der
Server kann die Datei beim Beenden neu schreiben und Änderungen überschreiben,
wenn sie während des Betriebs vorgenommen werden.

Vor manuellen Änderungen immer ein Backup des vollständigen
Galaxieverzeichnisses anlegen.

RCON-Passwörter oder Serverpasswörter sind sensible Daten. Werden sie später
über server.ini eingerichtet, sollte auch dieses Verzeichnis vor unberechtigtem
Zugriff geschützt werden.


9. VOLLSTÄNDIGKEIT UND VERSIONSPRÜFUNG
======================================

Die in Abschnitt 7 aufgeführten Optionen entsprechen der dokumentierten
Avorion-Kommandozeilenoberfläche:

    --help
    --port
    --max-players
    --save-interval
    --server-name
    --galaxy-name
    --datapath
    --admin
    --seed
    --difficulty
    --infinite-resources
    --collision-damage
    --same-start-sector
    --threads
    -t / --trace
    --exit-on-last-admin-logout
    --stderr-to-log
    --stdout-to-log
    --public
    --listed
    --use-steam-networking

Avorion kann Optionen zwischen Spielversionen ergänzen, ändern oder entfernen.
Die offizielle Wiki-Seite weist selbst darauf hin, dass ihre Serverdokumentation
teilweise veraltet sein kann. Maßgeblich ist deshalb immer die Ausgabe von:

    /opt/avorion/server.sh --help

innerhalb der tatsächlich installierten Serverversion.


10. QUELLEN UND WEITERFÜHRENDE DOKUMENTATION
============================================

Official Avorion Wiki – Setting up a server:
https://avorion.fandom.com/wiki/Setting_up_a_server

Official Avorion Wiki – Server / Command Line Options:
https://avorion.fandom.com/wiki/Server

Official Avorion Wiki – Difficulty:
https://avorion.fandom.com/wiki/Difficulty

SteamCMD-Dokumentation von Valve:
https://developer.valvesoftware.com/wiki/SteamCMD


10. FEHLERBEHEBUNG: BUILD BRICHT MIT EXIT-CODE 4 AB
===================================================

Fehlerbild:

    The command '... groupadd --gid 1000 avorion ...' returned a non-zero code: 4

Ursache:
Einige Ubuntu-24.04-Basis-Images enthalten bereits einen Benutzer oder eine
Gruppe mit UID beziehungsweise GID 1000. groupadd beendet sich mit Code 4, wenn
eine explizit angeforderte GID bereits verwendet wird.

Die mitgelieferte korrigierte Dockerfile verwendet deshalb beim Image-Build eine
automatisch freie System-UID und System-GID für den Benutzer avorion. Erst beim
Containerstart stellt entrypoint.sh den Benutzer auf PUID und PGID aus der .env
um. Dadurch können weiterhin PUID=1000 und PGID=1000 für die Host-Dateirechte
verwendet werden, ohne dass der Image-Build an einer bereits belegten ID
scheitert.

Nach dem Austausch der Dockerfile das Image ohne alten Build-Cache neu bauen:

    docker compose build --no-cache
    docker compose up -d

Die Meldung

    Docker Compose requires buildx plugin to be installed

ist von dem Exit-Code-4-Fehler unabhängig. Für den modernen BuildKit-Builder
kann auf Ubuntu mit der offiziellen Docker-Paketquelle das Buildx-Plugin
installiert werden:

    sudo apt update
    sudo apt install docker-buildx-plugin

Anschließend erneut bauen:

    docker compose build --no-cache
