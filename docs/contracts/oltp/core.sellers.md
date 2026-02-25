# Contrato - core.sellers

## Metadados

- Camada: OLTP
- Estado: rascunho
- Principais destinos no DW: `dim.DIM_VENDEDOR`, `dim.DIM_EQUIPE`

## Grao

Uma linha = um vendedor.

## Chaves

- Chave primaria: `seller_id`
- Chave de negocio: `seller_code` (unica)

## Incremental

- Watermark: `updated_at`
- Desempate: `seller_id`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| seller_id | BIGINT | nao | PK unica |
| seller_code | VARCHAR(50) | nao | chave de negocio unica |
| seller_name | VARCHAR(200) | nao | nao vazio |
| team_id | BIGINT | sim | FK para equipe |
| team_name | VARCHAR(150) | sim | atributo auxiliar |
| manager_seller_id | BIGINT | sim | autorreferencia permitida |
| monthly_goal_amount | DECIMAL(15,2) | sim | `>= 0` |
| seller_status | VARCHAR(20) | nao | `Ativo/Inativo` |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- sem duplicidade de `seller_code`
- valores permitidos para `seller_status`
- se `manager_seller_id` existir, deve existir na propria tabela

## Observacoes de Mapeamento DW

- atributos de vendedor alimentam `DIM_VENDEDOR`
- atributos de equipe alimentam/relacionam `DIM_EQUIPE`
- `monthly_goal_amount` apoia derivacao da fact de metas

