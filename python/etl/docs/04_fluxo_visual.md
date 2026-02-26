# Fluxo Visual do ETL (Fase 3)

Este documento traduz o fluxo da Fase 3 para diagramas.

## 1) Fluxo principal (alto nivel)

```mermaid
flowchart TD
    A[Iniciar run_etl.py] --> B[Abre conexao OLTP e DW]
    B --> C[Cria run_id em audit.etl_run status running]
    C --> D[Ler ctl.etl_control da entidade]
    D --> E[Registrar inicio em audit.etl_run_entity]
    E --> F[Extrair lote incremental do OLTP]
    F --> G{Ha registros?}
    G -- Nao --> H[Finaliza entidade success sem avancar watermark]
    G -- Sim --> I[Transformar dados em memoria]
    I --> J[Upsert Type 1 na dimensao DW]
    J --> K[Atualizar watermark em memoria]
    K --> L{Mais lotes?}
    L -- Sim --> F
    L -- Nao --> M[Atualizar ctl.etl_control com watermark final]
    M --> N[Finalizar audit.etl_run_entity success]
    H --> O[Finalizar audit.etl_run status success/partial/failed]
    N --> O
    O --> P[Fim]
```

## 2) Logica incremental (watermark composto)

```mermaid
flowchart LR
    A[watermark atual do controle] --> B[(watermark_updated_at, watermark_id)]
    B --> C[Query OLTP com filtro incremental]
    C --> D["updated_at > watermark_updated_at OR
updated_at = watermark_updated_at AND id > watermark_id"]
    D --> E[ORDER BY updated_at, id]
    E --> F[Ultimo registro do lote]
    F --> G[novo watermark]
    G --> H[Persistir no ctl.etl_control apenas em sucesso]
```

## 3) Sequencia entre componentes

```mermaid
sequenceDiagram
    participant R as run_etl.py
    participant C as ctl.etl_control
    participant O as OLTP core.customers
    participant D as DW dim.DIM_CLIENTE
    participant A as audit.etl_run / etl_run_entity

    R->>A: INSERT etl_run (running)
    R->>C: SELECT watermark/batch/cutoff da entidade
    R->>A: INSERT etl_run_entity (running)

    loop por lote
        R->>O: SELECT incremental ORDER BY updated_at,id
        O-->>R: linhas do lote
        R->>R: transformacoes / normalizacao
        R->>D: MERGE (upsert Type 1)
        R->>R: atualiza watermark em memoria
    end

    alt sucesso
        R->>C: UPDATE watermark + last_status=success
        R->>A: UPDATE etl_run_entity (success)
    else falha
        R->>R: rollback
        R->>C: UPDATE last_status=failed
        R->>A: UPDATE etl_run_entity (failed)
    end

    R->>A: UPDATE etl_run (success/partial/failed)
```

## 4) Estados de execucao

```mermaid
stateDiagram-v2
    [*] --> running
    running --> success: todas entidades ok
    running --> partial: parte ok, parte falhou
    running --> failed: erro geral ou todas falharam
    success --> [*]
    partial --> [*]
    failed --> [*]
```

## 5) Dry-run vs execucao real

```mermaid
flowchart TD
    A[Extrair e transformar lote] --> B{--dry-run?}
    B -- Sim --> C[nao faz upsert]
    C --> D[nao atualiza watermark]
    D --> E[apenas logs de auditoria]
    B -- Nao --> F[faz MERGE na dimensao]
    F --> G[atualiza watermark no controle]
    G --> H[fecha auditoria com sucesso/falha]
```
