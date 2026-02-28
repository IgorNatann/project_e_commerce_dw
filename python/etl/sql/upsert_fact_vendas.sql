MERGE fact.FACT_VENDAS AS target
USING
(
    SELECT
        ? AS venda_original_id,
        ? AS data_id,
        ? AS cliente_id,
        ? AS produto_id,
        ? AS regiao_id,
        ? AS vendedor_id,
        ? AS quantidade_vendida,
        ? AS preco_unitario_tabela,
        ? AS valor_total_bruto,
        ? AS valor_total_descontos,
        ? AS valor_total_liquido,
        ? AS custo_total,
        ? AS quantidade_devolvida,
        ? AS valor_devolvido,
        ? AS percentual_comissao,
        ? AS valor_comissao,
        ? AS numero_pedido,
        ? AS teve_desconto
) AS source
    ON target.venda_original_id = source.venda_original_id
WHEN MATCHED THEN
    UPDATE SET
        target.data_id = source.data_id,
        target.cliente_id = source.cliente_id,
        target.produto_id = source.produto_id,
        target.regiao_id = source.regiao_id,
        target.vendedor_id = source.vendedor_id,
        target.quantidade_vendida = source.quantidade_vendida,
        target.preco_unitario_tabela = source.preco_unitario_tabela,
        target.valor_total_bruto = source.valor_total_bruto,
        target.valor_total_descontos = source.valor_total_descontos,
        target.valor_total_liquido = source.valor_total_liquido,
        target.custo_total = source.custo_total,
        target.quantidade_devolvida = source.quantidade_devolvida,
        target.valor_devolvido = source.valor_devolvido,
        target.percentual_comissao = source.percentual_comissao,
        target.valor_comissao = source.valor_comissao,
        target.numero_pedido = source.numero_pedido,
        target.teve_desconto = source.teve_desconto,
        target.data_atualizacao = GETDATE()
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        venda_original_id,
        data_id,
        cliente_id,
        produto_id,
        regiao_id,
        vendedor_id,
        quantidade_vendida,
        preco_unitario_tabela,
        valor_total_bruto,
        valor_total_descontos,
        valor_total_liquido,
        custo_total,
        quantidade_devolvida,
        valor_devolvido,
        percentual_comissao,
        valor_comissao,
        numero_pedido,
        teve_desconto,
        data_inclusao,
        data_atualizacao
    )
    VALUES
    (
        source.venda_original_id,
        source.data_id,
        source.cliente_id,
        source.produto_id,
        source.regiao_id,
        source.vendedor_id,
        source.quantidade_vendida,
        source.preco_unitario_tabela,
        source.valor_total_bruto,
        source.valor_total_descontos,
        source.valor_total_liquido,
        source.custo_total,
        source.quantidade_devolvida,
        source.valor_devolvido,
        source.percentual_comissao,
        source.valor_comissao,
        source.numero_pedido,
        source.teve_desconto,
        GETDATE(),
        GETDATE()
    );
