# Contrato Global de Dados (Fase 0)

Versao: `0.1.0`  
Estado: `rascunho`  
Escopo: `contratos de origem OLTP para cargas no DW_ECOMMERCE`

## 1. Padrao Temporal

- Todos os timestamps devem ser armazenados em UTC.
- Campos obrigatorios de controle nas tabelas de origem:
  - `created_at` (obrigatorio)
  - `updated_at` (obrigatorio)
  - `deleted_at` (anulavel, exclusao logica)

## 2. Padrao de Extracao Incremental

- Watermark baseline: `(updated_at, id)`.
- Ordenacao: `ORDER BY updated_at, id`.
- Estrategia de paginacao: keyset pagination (sem `OFFSET`).
- Cutoff de seguranca: processar linhas com `updated_at <= now_utc - 5 minutes`.

## 3. Politica de Exclusao

- OLTP usa exclusao logica (`deleted_at IS NOT NULL`).
- A carga no DW deve tratar linhas soft-deletadas como inativas (ou status equivalente de negocio).

## 4. Convencoes de Tipos

- Campos monetarios: `DECIMAL(15,2)`.
- Campos de quantidade: tipos inteiros.
- Flags: `BIT` (0 ou 1).
- Situacao de negocio: `VARCHAR` com dominio controlado.

## 5. Baseline de Qualidade

Expectativas minimas por entidade de origem:

- unicidade de chave primaria;
- unicidade de chave de negocio (quando aplicavel);
- campos obrigatorios nao nulos;
- integridade referencial com entidades pai;
- `updated_at >= created_at`.

## 6. Politica de Quebra de Contrato

Mudancas que configuram quebra de contrato:

- renomear/remover coluna de origem usada pelo ETL;
- alterar semantica de campo existente;
- alterar chave primaria ou chave de negocio.

Acoes obrigatorias quando houver quebra:

1. atualizar arquivo de contrato;
2. atualizar arquivo de mapeamento;
3. registrar nota de migracao no PR;
4. atualizar testes e checks do ETL.

