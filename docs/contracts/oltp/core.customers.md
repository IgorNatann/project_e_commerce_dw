# Contrato - core.customers

## Metadados

- Camada: OLTP
- Estado: rascunho
- Principal destino no DW: `dim.DIM_CLIENTE`

## Grao

Uma linha = um perfil de cliente.

## Chaves

- Chave primaria: `customer_id`
- Chave de negocio: `customer_code` (unica)

## Incremental

- Watermark: `updated_at`
- Desempate: `customer_id`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| customer_id | BIGINT | nao | PK unica |
| customer_code | VARCHAR(50) | nao | chave de negocio unica |
| full_name | VARCHAR(200) | nao | nao vazio |
| email | VARCHAR(200) | sim | formato valido quando preenchido |
| phone | VARCHAR(30) | sim | formato normalizado |
| birth_date | DATE | sim | `<= current_date` |
| city | VARCHAR(100) | sim | - |
| state | VARCHAR(2) | sim | padrao UF BR |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- sem duplicidade de `customer_code`
- sem nulos em `customer_id`, `customer_code`, `full_name`
- `updated_at >= created_at`

## Observacoes de Mapeamento DW

- `customer_id` -> `cliente_original_id`
- `full_name` -> `nome_cliente`
- `email`, `phone`, `city`, `state` -> atributos correspondentes de cliente
- `deleted_at IS NOT NULL` deve ser mapeado para flag de inativo no DW

