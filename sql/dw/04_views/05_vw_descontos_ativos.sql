PRINT '========================================';
PRINT 'CRIANDO VIEW AUXILIAR';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('dim.VW_DESCONTOS_ATIVOS', 'V') IS NOT NULL
    DROP VIEW dim.VW_DESCONTOS_ATIVOS;
GO

CREATE VIEW dim.VW_DESCONTOS_ATIVOS
AS
/*
    View: VW_DESCONTOS_ATIVOS
    Proposito: Mostrar apenas descontos validos e utilizaveis
    Uso: SELECT * FROM dim.VW_DESCONTOS_ATIVOS
*/
SELECT 
    desconto_id,
    desconto_original_id,
    codigo_desconto,
    nome_campanha,
    descricao,
    tipo_desconto,
    metodo_desconto,
    valor_desconto,
    -- Regras
    min_valor_compra_regra,
    max_valor_desconto_regra,
    max_usos_por_cliente,
    max_usos_total,
    aplica_em,
    restricao_produtos,
    restricao_clientes,
    -- Validade
    data_inicio_validade,
    data_fim_validade,
    CASE 
        WHEN data_fim_validade IS NULL THEN 'Sem Expiração'
        ELSE 'Válido'
    END AS status_validade,
    DATEDIFF(DAY, GETDATE(), data_fim_validade) AS dias_ate_expirar,
    -- Performance
    total_usos_realizados,
    total_receita_gerada,
    total_desconto_concedido,
    -- Controle
    origem_campanha,
    canal_divulgacao,
    eh_cumulativo,
    requer_aprovacao,
    -- Calculos
    CASE 
        WHEN total_usos_realizados > 0 
        THEN total_receita_gerada / total_usos_realizados
        ELSE 0
    END AS ticket_medio_com_desconto,
    CASE 
        WHEN total_usos_realizados > 0 
        THEN total_desconto_concedido / total_usos_realizados
        ELSE 0
    END AS desconto_medio_por_uso
FROM dim.DIM_DESCONTO
WHERE eh_ativo = 1 
  AND situacao = 'Ativo'
  AND data_inicio_validade <= GETDATE()
  AND (data_fim_validade IS NULL OR data_fim_validade >= GETDATE());
GO

PRINT 'Ok. View dim.VW_DESCONTOS_ATIVOS criada!';
PRINT '';
