# Contrato - core.orders

## Metadados

- Camada: OLTP
- Estado: rascunho
- Principais destinos no DW: `fact.FACT_VENDAS` (contexto do pedido), `fact.FACT_DESCONTOS`

## Grao

Uma linha = um pedido de venda.

## Chaves

- Chave primaria: `order_id`
- Chave de negocio: `order_number` (unica)

## Incremental

- Watermark: `updated_at`
- Desempate: `order_id`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| order_id | BIGINT | nao | PK unica |
| order_number | VARCHAR(50) | nao | chave de negocio unica |
| customer_id | BIGINT | nao | FK para cliente |
| seller_id | BIGINT | sim | FK para vendedor |
| region_code | VARCHAR(20) | sim | mapeia para dimensao de regiao |
| order_status | VARCHAR(20) | nao | dominio controlado |
| order_date | DATETIME2 | nao | data do evento de negocio |
| payment_status | VARCHAR(20) | sim | opcional na fase 0 |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- sem duplicidade de `order_number`
- chaves pai devem existir (`customer_id`, `seller_id` quando nao nulo)
- `order_date` nao pode ser nulo

## Observacoes de Mapeamento DW

- `order_number` -> `numero_pedido`
- `order_date` -> busca com `DIM_DATA` para obter `data_id`
- status pode definir regras de inclusao/exclusao de negocio nas facts

