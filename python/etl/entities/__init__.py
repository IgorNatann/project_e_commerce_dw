from __future__ import annotations

from . import dim_cliente
from . import dim_desconto
from . import dim_equipe
from . import dim_produto
from . import dim_regiao
from . import dim_vendedor
from . import fact_vendas


ENTITY_REGISTRY = {
    dim_cliente.ENTITY_NAME: dim_cliente,
    dim_desconto.ENTITY_NAME: dim_desconto,
    dim_equipe.ENTITY_NAME: dim_equipe,
    dim_produto.ENTITY_NAME: dim_produto,
    dim_regiao.ENTITY_NAME: dim_regiao,
    dim_vendedor.ENTITY_NAME: dim_vendedor,
    fact_vendas.ENTITY_NAME: fact_vendas,
}


def list_entities() -> list[str]:
    return sorted(ENTITY_REGISTRY.keys())


def get_entity(entity_name: str):
    entity = ENTITY_REGISTRY.get(entity_name)
    if entity is None:
        valid = ", ".join(list_entities())
        raise ValueError(f"Entidade '{entity_name}' nao suportada. Opcoes: {valid}")
    return entity
