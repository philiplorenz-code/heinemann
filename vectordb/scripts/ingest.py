#!/usr/bin/env python3
"""Lädt Markdown- oder PDF-Dokumente ein und erzeugt OpenAI-Embeddings."""

import argparse
import os
from pathlib import Path
import re

import psycopg
import yaml
from pypdf import PdfReader

from openai_embeddings import MODEL_NAME, create_embeddings, usage_summary

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://vectors:vectors@localhost:5432/vectors"
)
DEFAULT_DOCUMENTS_DIR = Path(__file__).resolve().parents[1] / "docs"


def split_into_chunks(text: str) -> list[str]:
    """Teilt Text an Absatzgrenzen und verwirft Überschriften."""
    return [
        paragraph.strip()
        for paragraph in re.split(r"\n\s*\n", text)
        if len(paragraph.strip()) > 80 and not paragraph.lstrip().startswith("#")
    ]


def read_markdown(path: Path) -> tuple[dict, list[str]]:
    """Liest YAML-Metadaten und teilt den Text an Absatzgrenzen."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError(f"{path} beginnt nicht mit YAML-Frontmatter")

    _, frontmatter, body = text.split("---", 2)
    metadata = yaml.safe_load(frontmatter)
    return metadata, split_into_chunks(body)


def read_pdf(path: Path) -> tuple[dict, list[str]]:
    """Extrahiert Text und sichtbare Metadaten aus einem durchsuchbaren PDF."""
    reader = PdfReader(path)
    text = "\n".join(page.extract_text() or "" for page in reader.pages)
    lines = [line.strip() for line in text.splitlines() if line.strip()]

    def field_value(label: str, default: str) -> str:
        match = re.search(
            rf"{label}:\s*(.*?)(?:\s+(?:Dokumententyp|Land|Version):|$)",
            text,
            flags=re.IGNORECASE,
        )
        return match.group(1).strip() if match else default

    metadata = {
        "department": field_value("Abteilung", "General"),
        "country": field_value("Land", "DE"),
    }
    content = "\n".join(
        line
        for line in lines
        if not any(
            marker in line.casefold()
            for marker in (
                "nordstern gmbh",
                "internal corporate governance",
                "abteilung:",
                "dokumententyp:",
                "land:",
                "version:",
            )
        )
        and not line.casefold().startswith(("seite ", "nordstern gmbh —"))
        and line not in metadata.values()
    )
    return metadata, split_into_chunks(content)


def read_document(path: Path) -> tuple[dict, list[str]]:
    if path.suffix.casefold() == ".md":
        return read_markdown(path)
    if path.suffix.casefold() == ".pdf":
        return read_pdf(path)
    raise ValueError(f"Nicht unterstütztes Dateiformat: {path}")


def as_pgvector(values) -> str:
    """Formatiert eine Zahlenliste als pgvector-Literal."""
    return "[" + ",".join(str(float(value)) for value in values) + "]"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=DEFAULT_DOCUMENTS_DIR,
        help="Ordner mit Markdown- oder PDF-Dokumenten",
    )
    args = parser.parse_args()
    source_dir = args.source_dir.resolve()
    if not source_dir.is_dir():
        raise RuntimeError(f"Quellordner nicht gefunden: {source_dir}")

    rows: list[tuple[str, str, str, str]] = []
    skipped: list[str] = []
    paths = sorted(
        path
        for pattern in ("*.md", "*.pdf")
        for path in source_dir.glob(pattern)
    )
    for path in paths:
        metadata, chunks = read_document(path)
        if not chunks:
            skipped.append(path.name)
            continue
        for chunk in chunks:
            rows.append(
                (path.name, metadata["department"], metadata["country"], chunk)
            )

    if not rows:
        raise RuntimeError(
            f"Keine durchsuchbaren Absätze unter {source_dir} gefunden. "
            "PDFs benötigen extrahierbaren Fließtext."
        )
    if skipped:
        print("Übersprungen (kein extrahierbarer Fließtext): " + ", ".join(skipped))

    print(f"Erzeuge Embeddings mit {MODEL_NAME} …")
    embeddings, tokens = create_embeddings([row[3] for row in rows])

    with psycopg.connect(DATABASE_URL) as connection:
        with connection.cursor() as cursor:
            cursor.execute("TRUNCATE documents RESTART IDENTITY")
            cursor.executemany(
                """INSERT INTO documents
                   (source, department, country, content, embedding)
                   VALUES (%s, %s, %s, %s, %s::vector)""",
                [
                    (*row, as_pgvector(embedding))
                    for row, embedding in zip(rows, embeddings, strict=True)
                ],
            )
    print(
        f"{len(rows)} Absätze aus {len(set(row[0] for row in rows))} "
        "Dokumenten importiert."
    )
    print(usage_summary(tokens))


if __name__ == "__main__":
    main()
