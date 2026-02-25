# Modelo de Contrato por Entidade

## Metadados

- Entidade:
- Camada:
- Responsavel:
- Estado: rascunho | ativo | descontinuado

## Grao

Uma linha representa:

## Chaves

- Chave primaria:
- Chave de negocio:

## Incremental

- Coluna watermark: `updated_at`
- Desempate: `<coluna_pk>`
- Ordenacao de extracao: `updated_at, <coluna_pk>`

## Colunas Obrigatorias

| Coluna | Tipo | Nulo | Regra |
|---|---|---|---|
| id | BIGINT | nao | PK unica |
| created_at | DATETIME2 | nao | UTC |
| updated_at | DATETIME2 | nao | UTC, `>= created_at` |
| deleted_at | DATETIME2 | sim | exclusao logica |

## Checks de Qualidade de Dados

- unicidade de PK
- colunas obrigatorias nao nulas
- consistencia temporal
- integridade de FK (quando aplicavel)

## Destinos no DW

- Tabelas de destino:
- Observacoes de transformacao:

## Historico de Mudancas

- AAAA-MM-DD - descricao da mudanca
