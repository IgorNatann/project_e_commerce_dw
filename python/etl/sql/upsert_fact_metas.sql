MERGE fact.FACT_METAS AS target
USING
(
    SELECT
        ? AS vendedor_id,
        ? AS data_id,
        ? AS tipo_periodo,
        ? AS valor_meta,
        ? AS quantidade_meta,
        ? AS valor_realizado,
        ? AS quantidade_realizada,
        ? AS percentual_atingido,
        ? AS gap_meta,
        ? AS ticket_medio_realizado,
        ? AS meta_batida,
        ? AS meta_superada,
        ? AS eh_periodo_fechado,
        ? AS data_inclusao,
        ? AS data_ultima_atualizacao
) AS source
    ON target.vendedor_id = source.vendedor_id
   AND target.data_id = source.data_id
   AND target.tipo_periodo = source.tipo_periodo
WHEN MATCHED THEN
    UPDATE SET
        target.valor_meta = source.valor_meta,
        target.quantidade_meta = source.quantidade_meta,
        target.valor_realizado = source.valor_realizado,
        target.quantidade_realizada = source.quantidade_realizada,
        target.percentual_atingido = source.percentual_atingido,
        target.gap_meta = source.gap_meta,
        target.ticket_medio_realizado = source.ticket_medio_realizado,
        target.meta_batida = source.meta_batida,
        target.meta_superada = source.meta_superada,
        target.eh_periodo_fechado = source.eh_periodo_fechado,
        target.data_ultima_atualizacao = source.data_ultima_atualizacao
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        vendedor_id,
        data_id,
        valor_meta,
        quantidade_meta,
        valor_realizado,
        quantidade_realizada,
        percentual_atingido,
        gap_meta,
        ticket_medio_realizado,
        meta_batida,
        meta_superada,
        eh_periodo_fechado,
        tipo_periodo,
        data_inclusao,
        data_ultima_atualizacao
    )
    VALUES
    (
        source.vendedor_id,
        source.data_id,
        source.valor_meta,
        source.quantidade_meta,
        source.valor_realizado,
        source.quantidade_realizada,
        source.percentual_atingido,
        source.gap_meta,
        source.ticket_medio_realizado,
        source.meta_batida,
        source.meta_superada,
        source.eh_periodo_fechado,
        source.tipo_periodo,
        source.data_inclusao,
        source.data_ultima_atualizacao
    );
