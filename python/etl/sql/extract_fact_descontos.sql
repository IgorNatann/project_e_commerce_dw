SELECT TOP ({batch_size})
    oid.order_item_discount_id,
    oid.order_item_id,
    oid.order_id,
    oid.discount_id,
    oid.application_level,
    oid.discount_amount,
    oid.base_amount,
    oid.final_amount,
    oid.applied_at,
    oid.approved,
    oid.rejection_reason,
    oid.created_at AS order_item_discount_created_at,
    oid.updated_at AS order_item_discount_updated_at,
    oid.deleted_at AS order_item_discount_deleted_at,
    oi.product_id,
    oi.updated_at AS order_item_updated_at,
    oi.deleted_at AS order_item_deleted_at,
    o.customer_id,
    o.order_number,
    o.updated_at AS order_updated_at,
    o.deleted_at AS order_deleted_at,
    src.source_updated_at
FROM core.order_item_discounts AS oid
INNER JOIN core.order_items AS oi
    ON oi.order_item_id = oid.order_item_id
INNER JOIN core.orders AS o
    ON o.order_id = oid.order_id
CROSS APPLY
(
    SELECT
        CASE
            WHEN oid.updated_at >= oi.updated_at AND oid.updated_at >= o.updated_at THEN oid.updated_at
            WHEN oi.updated_at >= o.updated_at THEN oi.updated_at
            ELSE o.updated_at
        END AS source_updated_at
) AS src
WHERE
    src.source_updated_at <= ?
    AND
    (
        src.source_updated_at > ?
        OR (src.source_updated_at = ? AND oid.order_item_discount_id > ?)
    )
ORDER BY
    src.source_updated_at ASC,
    oid.order_item_discount_id ASC;
