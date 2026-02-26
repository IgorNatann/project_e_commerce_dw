from __future__ import annotations

from . import dim_cliente


ENTITY_REGISTRY = {
    dim_cliente.ENTITY_NAME: dim_cliente,
}


def list_entities() -> list[str]:
    return sorted(ENTITY_REGISTRY.keys())


def get_entity(entity_name: str):
    entity = ENTITY_REGISTRY.get(entity_name)
    if entity is None:
        valid = ", ".join(list_entities())
        raise ValueError(f"Entidade '{entity_name}' nao suportada. Opcoes: {valid}")
    return entity
