"""Gemeinsame OpenAI-Konfiguration und Kostenanzeige für die Demo."""

from decimal import Decimal
import os

from openai import OpenAI


MODEL_NAME = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
EMBEDDING_DIMENSIONS = 1536
LIST_PRICES_USD_PER_MILLION = {
    "text-embedding-3-small": Decimal("0.02"),
    "text-embedding-3-large": Decimal("0.13"),
}


def create_embeddings(texts: list[str]) -> tuple[list[list[float]], int]:
    """Erzeugt Embeddings und gibt zusätzlich die API-Tokenzahl zurück."""
    if MODEL_NAME not in LIST_PRICES_USD_PER_MILLION:
        raise RuntimeError(
            "Diese Demo unterstützt text-embedding-3-small und "
            "text-embedding-3-large."
        )

    response = OpenAI().embeddings.create(
        model=MODEL_NAME,
        input=texts,
        dimensions=EMBEDDING_DIMENSIONS,
        encoding_format="float",
    )
    ordered = sorted(response.data, key=lambda item: item.index)
    return [item.embedding for item in ordered], response.usage.total_tokens


def usage_summary(tokens: int) -> str:
    """Formatiert Tokenverbrauch und Kosten zum konfigurierten Preis."""
    configured_price = os.getenv("OPENAI_EMBEDDING_PRICE_USD_PER_MILLION")
    price = (
        Decimal(configured_price)
        if configured_price
        else LIST_PRICES_USD_PER_MILLION[MODEL_NAME]
    )
    cost = Decimal(tokens) * price / Decimal(1_000_000)
    return (
        f"Embedding-Nutzung: {tokens} Tokens mit {MODEL_NAME}; "
        f"berechnete Kosten: {cost:.8f} US-Dollar "
        f"({price} US-Dollar je 1 Mio. Tokens)."
    )
