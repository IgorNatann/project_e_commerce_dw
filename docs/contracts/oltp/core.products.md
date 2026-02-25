# Contrato - core.products

## Metadados

- Camada: OLTP
- Estado: rascunho
- Principal destino no DW: `dim.DIM_PRODUTO`

## Grao

Uma linha = um SKU de produto.

## Chaves

- Chave primaria: `product_id`
- Chave de negocio: `sku` (unica)

## Incremental

- Watermark: `updated_at`
- Desempate: `product_id`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| product_id | BIGINT | nao | PK unica |
| sku | VARCHAR(50) | nao | chave de negocio unica |
| product_name | VARCHAR(200) | nao | nao vazio |
| category_name | VARCHAR(100) | nao | nao vazio |
| subcategory_name | VARCHAR(100) | sim | - |
| supplier_id | BIGINT | nao | FK para fornecedor |
| supplier_name | VARCHAR(150) | nao | atributo auxiliar denormalizado permitido |
| cost_price | DECIMAL(15,2) | nao | `>= 0` |
| list_price | DECIMAL(15,2) | nao | `>= 0` |
| product_status | VARCHAR(20) | nao | `Ativo/Inativo/Descontinuado` |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- sem duplicidade de `sku`
- `cost_price` e `list_price` nao negativos
- valores permitidos para `product_status`

## Observacoes de Mapeamento DW

- `product_id` -> `produto_original_id`
- `sku` -> `codigo_sku`
- `product_name` -> `nome_produto`
- `cost_price` -> `preco_custo`
- `list_price` -> `preco_sugerido`
- `product_status` -> `situacao`

