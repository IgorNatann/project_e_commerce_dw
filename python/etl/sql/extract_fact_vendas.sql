SELECT TOP ({batch_size})
    oi.order_item_id,
    oi.order_id,
    oi.item_number,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.gross_amount,
    oi.discount_amount,
    oi.net_amount,
    oi.cost_amount,
    oi.return_quantity,
    oi.returned_amount,
    oi.commission_percent,
    oi.commission_amount,
    oi.had_discount,
    oi.created_at AS order_item_created_at,
    oi.updated_at AS order_item_updated_at,
    oi.deleted_at AS order_item_deleted_at,
    o.order_number,
    o.order_date,
    o.customer_id,
    o.seller_id,
    COALESCE(o.region_id, rc.region_id) AS resolved_region_id,
    o.updated_at AS order_updated_at,
    o.deleted_at AS order_deleted_at,
    src.source_updated_at
FROM core.order_items AS oi
INNER JOIN core.orders AS o
    ON o.order_id = oi.order_id
LEFT JOIN core.customers AS c
    ON c.customer_id = o.customer_id
LEFT JOIN core.regions AS rc
    ON rc.state = c.state
   AND rc.city = c.city
   AND rc.deleted_at IS NULL
CROSS APPLY
(
    SELECT
        CASE
            WHEN o.updated_at > oi.updated_at THEN o.updated_at
            ELSE oi.updated_at
        END AS source_updated_at
) AS src
WHERE
    src.source_updated_at <= ?
    AND
    (
        src.source_updated_at > ?
        OR (src.source_updated_at = ? AND oi.order_item_id > ?)
    )
ORDER BY
    src.source_updated_at ASC,
    oi.order_item_id ASC;
