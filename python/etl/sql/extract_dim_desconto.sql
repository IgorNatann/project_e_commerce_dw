SELECT TOP ({batch_size})
    d.discount_id,
    d.discount_code,
    d.campaign_name,
    d.description,
    d.discount_type,
    d.discount_method,
    d.discount_value,
    d.min_order_value,
    d.max_discount_value,
    d.max_uses_per_customer,
    d.max_uses_total,
    d.apply_scope,
    d.product_restriction,
    d.start_at,
    d.end_at,
    d.is_active,
    d.is_stackable,
    d.approval_required,
    d.current_usage_count,
    d.total_revenue_generated,
    d.total_discount_given,
    d.created_at,
    d.updated_at,
    d.deleted_at
FROM core.discount_campaigns AS d
WHERE
    d.updated_at <= ?
    AND
    (
        d.updated_at > ?
        OR (d.updated_at = ? AND d.discount_id > ?)
    )
ORDER BY
    d.updated_at ASC,
    d.discount_id ASC;
