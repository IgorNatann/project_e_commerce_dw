# Contrato - core.order_items

## Metadados

- Camada: OLTP
- Estado: rascunho
- Principal destino no DW: `fact.FACT_VENDAS`

## Grao

Uma linha = um item de produto dentro de um pedido.

## Chaves

- Chave primaria: `order_item_id`
- Chave de negocio: `(order_id, item_number)` unica

## Incremental

- Watermark: `updated_at`
- Desempate: `order_item_id`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| order_item_id | BIGINT | nao | PK unica |
| order_id | BIGINT | nao | FK para orders |
| item_number | INT | nao | sequencial por pedido |
| product_id | BIGINT | nao | FK para products |
| quantity | INT | nao | `> 0` |
| unit_price | DECIMAL(15,2) | nao | `>= 0` |
| gross_amount | DECIMAL(15,2) | nao | `>= 0` |
| discount_amount | DECIMAL(15,2) | nao | `>= 0` |
| net_amount | DECIMAL(15,2) | nao | `gross_amount - discount_amount` |
| return_quantity | INT | sim | `>= 0` |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- unicidade de `(order_id, item_number)`
- sem orfaos de `order_id` ou `product_id`
- regra financeira exata para valor liquido
- `return_quantity <= quantity` quando preenchido

## Observacoes de Mapeamento DW

- uma linha de origem geralmente mapeia para uma linha em `FACT_VENDAS`
- `gross_amount` -> `valor_total_bruto`
- `discount_amount` -> `valor_total_descontos`
- `net_amount` -> `valor_total_liquido`
- campos de devolucao suportam metricas de devolucao

