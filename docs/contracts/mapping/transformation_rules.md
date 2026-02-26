# Regras de Transformacao - Fase 2

Este arquivo define o catalogo de regras usadas na matriz `oltp_to_dw_mapping.csv`.

## 1. Normalizacao de status e enums

- `normalizar_status_produto`:
  - `Ativo -> Ativo`
  - `Inativo -> Inativo`
  - `Descontinuado -> Descontinuado`
  - valor fora do dominio -> `N/A` + log de rejeicao.
- `normalizar_status_vendedor`:
  - `Ativo -> Ativo`
  - `Inativo -> Inativo`
  - nulo -> `Inativo`.
- `normalizar_tipo_cliente`:
  - valores aceitos: `Novo`, `Recorrente`, `Inativo`, `PF`, `PJ`.
  - valor fora do dominio -> `Nao Classificado`.
- `normalizar_categoria_valor`:
  - valores aceitos: `Baixo`, `Medio`, `Alto`, `Premium`.
  - valor fora do dominio -> `Nao Classificado`.
- `normalizar_tipo_desconto`:
  - padrao `Percentual`, `Valor Fixo`, `Frete`, `Cashback`.
  - outros valores -> `Outro`.
- `normalizar_tipo_equipe`:
  - padrao `Inside Sales`, `Field Sales`, `Canal`, `Ecommerce`.
  - valor fora do dominio -> `Nao Classificado`.
- `normalizar_metodo_desconto`:
  - padrao `Cupom`, `Campanha`, `Automatico`, `Manual`.
- `normalizar_escopo_desconto`:
  - padrao `Pedido`, `Produto`, `Frete`.
- `normalizar_nivel_aplicacao`:
  - padrao `Pedido`, `Produto`, `Frete`.
- `normalizar_tipo_periodo`:
  - padrao `Mensal`.
- `normalizar_genero`:
  - padrao `M`, `F`, `Outro`, `Nao Informado`.
- `status_para_bool`:
  - `Ativo -> 1`
  - `Inativo -> 0`.
- `bit_para_bool`:
  - `1 -> 1`
  - `0 -> 0`.
- `bit_para_status_ativo_inativo`:
  - `1 -> Ativo`
  - `0 -> Inativo`.
- `regra_status_aceita_clientes`:
  - `Ativo -> 1`
  - `Inativo -> 0`.

## 2. Normalizacao de texto

- `normalizar_texto_titulo`:
  - `TRIM`, reduzir espacos internos e aplicar capitalizacao de titulo.
- `normalizar_texto`:
  - `TRIM`, reduzir espacos internos, manter caixa original.
- `normalizar_email`:
  - `TRIM`, `LOWER`, validar formato basico.
- `normalizar_telefone`:
  - remover mascara e manter apenas digitos.
- `normalizar_documento`:
  - remover mascara de CPF/CNPJ e manter apenas digitos.
- `normalizar_cep`:
  - remover mascara e manter 8 digitos.
- `normalizar_uf`:
  - `UPPER`, validar contra lista de UFs.
- `normalizar_pais`:
  - `TRIM`, mapear sinonimos (`Brasil`/`BR` -> `Brasil`).
- `normalizar_keywords`:
  - separar por virgula, `TRIM` por item, remover duplicados.

## 3. Regras numericas e monetarias

- `clamp_score_credito`:
  - limitar entre `0` e `1000`.
- `direto`:
  - carga 1:1 sem ajuste de valor.
- `nao_mapeado_r1`:
  - coluna fora do escopo R1 e sem carga no DW nesta release.
- `r1_assume_brl`:
  - no R1, valores monetarios sao tratados como BRL.
  - se `currency_code <> BRL`, registrar rejeicao para tratamento futuro.

## 4. Regras de lookup entre OLTP e DW

- `buscar_dim_data_por_data`: lookup por data calendario.
- `buscar_dim_data_primeiro_dia_mes`: usa dia 1 do mes de referencia.
- `buscar_dim_cliente_por_original`: lookup em `dim.DIM_CLIENTE.cliente_original_id`.
- `buscar_dim_produto_por_original`: lookup em `dim.DIM_PRODUTO.produto_original_id`.
- `buscar_dim_regiao_por_original`: lookup em `dim.DIM_REGIAO.regiao_original_id`.
- `buscar_dim_vendedor_por_original`: lookup em `dim.DIM_VENDEDOR.vendedor_original_id`.
- `buscar_dim_equipe_por_original`: lookup em `dim.DIM_EQUIPE.equipe_original_id`.
- `buscar_dim_desconto_por_original`: lookup em `dim.DIM_DESCONTO.desconto_original_id`.
- `buscar_fact_vendas_por_chave_origem`: lookup da venda via chave de negocio de carga.
- `buscar_supplier_name_por_id`: enrich do nome de fornecedor via `core.suppliers`.
- `buscar_regional_por_region_id`: enrich da regional para equipe via `core.regions`.
- `buscar_estado_por_region_id`: enrich do estado sede para equipe via `core.regions`.
- `buscar_cidade_por_region_id`: enrich da cidade sede para equipe via `core.regions`.
- `buscar_nome_equipe_por_team_id`: enrich do nome da equipe para vendedor via `core.teams`.
- `buscar_nome_gerente_por_manager_id`: enrich do nome de gerente via autorrelacao em `core.sellers`.

Se lookup falhar, aplicar fallback de chave desconhecida `-1` conforme `docs/contracts/00_global.md`.

## 5. Regras derivadas

- `calcular_percentual_atingido`: `(valor_realizado / NULLIF(valor_meta,0)) * 100`.
- `calcular_gap_meta`: `valor_realizado - valor_meta`.
- `calcular_ticket_medio_realizado`: `valor_realizado / NULLIF(quantidade_realizada,0)`.
- `calcular_meta_batida`: `percentual_atingido >= 100`.
- `calcular_meta_superada`: `percentual_atingido > 120`.
- `calcular_meta_trimestral`: `meta_mensal_base * 3`.
- `calcular_meta_trimestral_equipe`: soma das metas mensais da equipe em 3 meses.
- `calcular_meta_anual_equipe`: soma das metas mensais da equipe em 12 meses.
- `calcular_percentual_desconto`: `(valor_desconto_aplicado / NULLIF(valor_sem_desconto,0)) * 100`.
- `calcular_margem_antes_desconto`: `valor_sem_desconto - custo_total`.
- `calcular_margem_apos_desconto`: `valor_com_desconto - custo_total`.
- `calcular_impacto_margem`: `margem_antes_desconto - margem_apos_desconto`.
- `calcular_ranking_periodo`: ranking por periodo com base em `valor_realizado`.
- `calcular_quartil_performance`: quartil por periodo com base em `valor_realizado`.

## 6. Regras de agregacao (SCD Type 1)

- Agregacoes de historico em dimensoes (`DIM_CLIENTE`, `DIM_EQUIPE`) sobrescrevem valor atual.
- A estrategia do projeto continua `SCD Type 1` para R1.
- `agregar_count_pedidos`: total de pedidos por cliente.
- `agregar_sum_net_amount_por_cliente`: soma de `net_amount` por cliente.
- `agregar_ticket_medio_por_cliente`: media por pedido de cada cliente.
- `agregar_sum_meta_equipe`: soma de `monthly_goal_amount` por equipe.
- `agregar_sum_meta_quantidade_equipe`: soma da meta de quantidade por equipe.
- `agregar_count_membros_equipe`: total de vendedores ativos por equipe.
- `derivar_lider_por_equipe`: vendedor com `manager_seller_id` nulo e maior senioridade na equipe.
- `derivar_flag_lider`: vendedor que aparece como manager de outro vendedor na mesma equipe.
