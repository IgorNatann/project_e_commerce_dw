SELECT TOP ({batch_size})
    stm.seller_target_id,
    stm.seller_id,
    stm.target_month,
    stm.target_amount,
    stm.target_quantity,
    stm.realized_amount,
    stm.realized_quantity,
    stm.period_type,
    stm.period_closed,
    stm.created_at AS target_created_at,
    stm.updated_at AS target_updated_at,
    stm.deleted_at AS target_deleted_at
FROM core.seller_targets_monthly AS stm
WHERE
    stm.updated_at <= ?
    AND
    (
        stm.updated_at > ?
        OR (stm.updated_at = ? AND stm.seller_target_id > ?)
    )
ORDER BY
    stm.updated_at ASC,
    stm.seller_target_id ASC;
