# Vektordatenbanken: Praxisbeispiel mit pgvector

Begleitmaterial zum IT-Administrator-Artikel **„Treffer mit Bedeutung – Vektordatenbanken für die semantische Suche vergleichen“**.

Das Beispiel liest neun fiktive Unternehmensrichtlinien ein, zerlegt sie an Absatzgrenzen und erzeugt OpenAI-Embeddings. PostgreSQL speichert Text, Metadaten und Vektoren über pgvector. Ein zweites Skript durchsucht den Bestand in natürlicher Sprache und kann die Treffer anhand der Metadaten `department` und `country` filtern.

## Voraussetzungen

- Docker mit Docker Compose v2
- Python 3.10 oder neuer
- OpenAI-API-Zugang

Die Beispiele sind für eine lokale Demo vorgesehen. PostgreSQL lauscht ausschließlich auf `127.0.0.1:5432`; Benutzername und Passwort lauten jeweils `vectors`.

## Schnellstart

```bash
docker compose up -d
docker compose exec postgres pg_isready -U vectors -d vectors

python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

read -s OPENAI_API_KEY
export OPENAI_API_KEY
python scripts/ingest.py --source-dir docs
```

Der Import erzeugt aus den neun Markdown-Dateien 18 Abschnitte. Er ersetzt den Inhalt der Demotabelle vollständig und gibt anschließend die von der OpenAI-API gemeldete Tokenzahl sowie die daraus berechneten Kosten aus.

## Suchfragen aus dem Artikel

```bash
python scripts/search.py --limit 3 \
  "Wie teuer darf mein Hotel auf einer Geschäftsreise sein?"

python scripts/search.py --limit 3 \
  "Bis wann muss ich nach der Dienstreise meine Belege einreichen?"

python scripts/search.py --department IT --country DE --limit 3 \
  "Wie prüfen wir, ob sich gesicherte Daten zurückspielen lassen?"
```

Erwartete Fundstellen:

| Frage | Erwarteter Inhalt |
| --- | --- |
| Hotelkosten | `reiserichtlinie.md`: 150 Euro pro Nacht; höhere Kosten vor der Buchung genehmigen lassen |
| Frist für Reisekosten | `reisekostenabrechnung.md`: innerhalb von zehn Arbeitstagen |
| Wiederherstellung prüfen | `backup-richtlinie.md`: monatlicher Test für kritische Systeme |
| Zugangsdaten auf Phishing-Seite eingegeben | `phishing-notfallplan.md`: Passwort zurücksetzen und IT-Service-Desk informieren |
| Kilometerpauschale für Privatfahrten | Keine Antwort im Bestand |

Die erwarteten Inhalte sind fachliche Soll-Fundstellen. Die Rangfolge kann sich mit Modell und Datenbestand ändern. Das Beispiel erzeugt keine Antwort mit einem Sprachmodell, sondern gibt die gefundenen Textabschnitte aus.

## Filter prüfen

```bash
python scripts/search.py --department HR --country DE --limit 3 \
  "Wie teuer darf mein Hotel auf einer Geschäftsreise sein?"

python scripts/search.py --country AT --limit 3 \
  "Wie teuer darf mein Hotel auf einer Geschäftsreise sein?"
```

Der zweite Aufruf liefert im ausschließlich deutschen Testbestand keine Treffer. `department` und `country` sind fachliche Metadatenfilter; eine Benutzerautorisierung ersetzen sie nicht.

## Optionalen Vektorindex anlegen

Für die 18 Abschnitte reicht die vollständige Suche. Mit größeren Testbeständen lässt sich ein HNSW-Index ergänzen:

```bash
docker compose exec postgres psql -U vectors -d vectors \
  -c 'CREATE INDEX documents_embedding_hnsw ON documents USING hnsw (embedding vector_cosine_ops);'
```

Der Index ist für die Demo optional. Suchqualität und Antwortzeiten sollten mit repräsentativen Dokumenten und Filtern geprüft werden.

## Embedding-Modell und Kosten

Standardmäßig kommt `text-embedding-3-small` mit 1536 Dimensionen zum Einsatz. Import und Suche zeigen für jede API-Anfrage:

- das verwendete Modell,
- die von der API gemeldete Tokenzahl,
- die daraus berechneten Kosten.

Hinterlegt sind 0,02 US-Dollar je Million Tokens für `text-embedding-3-small` und 0,13 US-Dollar für `text-embedding-3-large`. Individuelle Vertrags- oder Batchpreise können abweichen. Einen abweichenden Preis übernimmt die Umgebungsvariable `OPENAI_EMBEDDING_PRICE_USD_PER_MILLION`.

Das größere Modell lässt sich mit derselben Vektorgröße testen:

```bash
OPENAI_EMBEDDING_MODEL=text-embedding-3-large \
  python scripts/ingest.py --source-dir docs

OPENAI_EMBEDDING_MODEL=text-embedding-3-large \
  python scripts/search.py \
  "Wie teuer darf mein Hotel auf einer Geschäftsreise sein?"
```

Import und Suche müssen dasselbe Modell verwenden. Nach einem Modellwechsel ist der vollständige Import erneut auszuführen.

## Eigene Dokumente einlesen

Das Importskript verarbeitet Markdown-Dateien mit YAML-Metadaten und durchsuchbare PDFs. Markdown-Dateien folgen diesem Aufbau:

```markdown
---
department: IT
country: DE
---

# Titel der Richtlinie

Dieser erste durchsuchbare Absatz enthält mehr als 80 Zeichen und beschreibt eine konkrete Regel für den späteren Suchtest.

Auch dieser zweite Absatz ist lang genug und ergänzt die Richtlinie um ein weiteres überprüfbares Detail.
```

Der einfache Splitter bildet Absätze und verwirft Überschriften sowie kürzere Textblöcke. Für eigene Dokumente sind Chunking, Tokenlimits, Textextraktion und Berechtigungen gesondert zu prüfen. Scans benötigen vor dem Import eine Texterkennung.

## Verzeichnisstruktur

```text
vectordb/
├── compose.yaml
├── requirements.txt
├── docs/                     Fiktive Richtlinien für den Soforttest
├── sql/
│   └── schema.sql            PostgreSQL-Schema mit pgvector
└── scripts/
    ├── ingest.py             Dokumentimport und Absatzaufteilung
    ├── openai_embeddings.py  Modell- und Kostenkonfiguration
    └── search.py             Vektorsuche mit optionalen Filtern
```

## Demo beenden

```bash
# Container stoppen, Daten behalten
docker compose down

# Container stoppen und Demo-Daten löschen
docker compose down -v
```

Das Schema wird beim ersten Start eines frischen Docker-Volumes initialisiert. Nach einer Änderung der Vektordimension ist daher ein neues Demo-Volume erforderlich.
