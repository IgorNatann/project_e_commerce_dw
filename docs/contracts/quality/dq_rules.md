# Regras de Qualidade de Dados (Fase 0)

## Conjunto Base de Regras

1. Unicidade de PK em todas as tabelas de origem.
2. Unicidade de chave de negocio quando definida.
3. Colunas obrigatorias nao podem ser nulas.
4. Linhas filhas nao podem referenciar pais inexistentes.
5. `updated_at` nao pode ser menor que `created_at`.
6. Linhas com exclusao logica devem manter chave de negocio imutavel.

## Regras de Integridade Financeira

Para linhas de item de pedido:

- `gross_amount >= 0`
- `discount_amount >= 0`
- `net_amount = gross_amount - discount_amount`
- `quantity > 0`
- `unit_price >= 0`

## Regras de Atualidade Operacional

- A execucao incremental nao deve processar linhas mais novas que o cutoff (`now_utc - 5 minutes`).
- Cada lote incremental deve reportar:
  - linhas extraidas
  - linhas carregadas
  - linhas rejeitadas

## Regras de Reconciliacao (OLTP vs DW)

- contagem de linhas por periodo
- soma(gross), soma(discount), soma(net) por periodo
- quantidade distinta de pedidos por periodo

Tolerancia para agregados na Fase 0: correspondencia exata (diferenca 0).
