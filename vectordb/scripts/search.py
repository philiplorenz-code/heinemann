#!/usr/bin/env python3
"""Durchsucht die Demo-Dokumente über Kosinus-Distanz."""

import argparse
import os

import psycopg

from openai_embeddings import create_embeddings, usage_summary

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://vectors:vectors@localhost:5432/vectors"
)


def as_pgvector(values) -> str:
    return "[" + ",".join(str(float(value)) for value in values) + "]"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("question", help="Frage in natürlicher Sprache")
    parser.add_argument("--country", help="Optionaler Länderfilter, etwa DE")
    parser.add_argument("--department", help="Optionaler Abteilungsfilter, etwa IT")
    parser.add_argument("--limit", type=int, default=5, help="Anzahl der Treffer")
    args = parser.parse_args()

    embeddings, tokens = create_embeddings([args.question])
    query_vector = as_pgvector(embeddings[0])

    filters: list[str] = []
    filter_values: list[str] = []
    if args.country:
        filters.append("country = %s")
        filter_values.append(args.country)
    if args.department:
        filters.append("department = %s")
        filter_values.append(args.department)

    where_clause = f"WHERE {' AND '.join(filters)}" if filters else ""
    statement = f"""
        SELECT source, content, 1 - (embedding <=> %s::vector) AS similarity
        FROM documents
        {where_clause}
        ORDER BY embedding <=> %s::vector
        LIMIT %s
    """
    parameters = [query_vector, *filter_values, query_vector, args.limit]

    with psycopg.connect(DATABASE_URL) as connection:
        with connection.cursor() as cursor:
            cursor.execute(statement, parameters)
            results = cursor.fetchall()

    if not results:
        print("Keine Treffer. Filter oder Datenbestand prüfen.")
        print(usage_summary(tokens))
        return

    for number, (source, content, similarity) in enumerate(results, start=1):
        print(f"{number}. {source} ({similarity:.3f})\n   {content}\n")
    print(usage_summary(tokens))


if __name__ == "__main__":
    main()
