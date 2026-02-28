MERGE fact.FACT_DESCONTOS AS target
USING
(
    SELECT
        ? AS desconto_aplicado_original_id,
        ? AS desconto_id,
        ? AS venda_id,
        ? AS data_aplicacao_id,
        ? AS cliente_id,
        ? AS produto_id,
        ? AS nivel_aplicacao,
        ? AS valor_desconto_aplicado,
        ? AS valor_sem_desconto,
        ? AS valor_com_desconto,
        ? AS margem_antes_desconto,
        ? AS margem_apos_desconto,
        ? AS impacto_margem,
        ? AS percentual_desconto_efetivo,
        ? AS desconto_aprovado,
        ? AS motivo_rejeicao,
        ? AS numero_pedido,
        ? AS data_inclusao,
        ? AS data_atualizacao
) AS source
    ON target.desconto_aplicado_original_id = source.desconto_aplicado_original_id
WHEN MATCHED THEN
    UPDATE SET
        target.desconto_id = source.desconto_id,
        target.venda_id = source.venda_id,
        target.data_aplicacao_id = source.data_aplicacao_id,
        target.cliente_id = source.cliente_id,
        target.produto_id = source.produto_id,
        target.nivel_aplicacao = source.nivel_aplicacao,
        target.valor_desconto_aplicado = source.valor_desconto_aplicado,
        target.valor_sem_desconto = source.valor_sem_desconto,
        target.valor_com_desconto = source.valor_com_desconto,
        target.margem_antes_desconto = source.margem_antes_desconto,
        target.margem_apos_desconto = source.margem_apos_desconto,
        target.impacto_margem = source.impacto_margem,
        target.percentual_desconto_efetivo = source.percentual_desconto_efetivo,
        target.desconto_aprovado = source.desconto_aprovado,
        target.motivo_rejeicao = source.motivo_rejeicao,
        target.numero_pedido = source.numero_pedido,
        target.data_atualizacao = source.data_atualizacao
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        desconto_aplicado_original_id,
        desconto_id,
        venda_id,
        data_aplicacao_id,
        cliente_id,
        produto_id,
        nivel_aplicacao,
        valor_desconto_aplicado,
        valor_sem_desconto,
        valor_com_desconto,
        margem_antes_desconto,
        margem_apos_desconto,
        impacto_margem,
        percentual_desconto_efetivo,
        desconto_aprovado,
        motivo_rejeicao,
        numero_pedido,
        data_inclusao,
        data_atualizacao
    )
    VALUES
    (
        source.desconto_aplicado_original_id,
        source.desconto_id,
        source.venda_id,
        source.data_aplicacao_id,
        source.cliente_id,
        source.produto_id,
        source.nivel_aplicacao,
        source.valor_desconto_aplicado,
        source.valor_sem_desconto,
        source.valor_com_desconto,
        source.margem_antes_desconto,
        source.margem_apos_desconto,
        source.impacto_margem,
        source.percentual_desconto_efetivo,
        source.desconto_aprovado,
        source.motivo_rejeicao,
        source.numero_pedido,
        source.data_inclusao,
        source.data_atualizacao
    );
