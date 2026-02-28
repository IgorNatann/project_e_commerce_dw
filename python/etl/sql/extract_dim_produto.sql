SELECT TOP ({batch_size})
    p.product_id,
    p.product_code,
    p.sku,
    p.barcode,
    p.product_name,
    p.short_description,
    p.full_description,
    p.category_name,
    p.subcategory_name,
    p.product_line,
    p.brand,
    p.manufacturer,
    p.supplier_id,
    s.supplier_name,
    p.country_origin,
    p.weight_kg,
    p.height_cm,
    p.width_cm,
    p.depth_cm,
    p.color,
    p.material,
    p.cost_price,
    p.list_price,
    p.suggested_margin_percent,
    p.is_perishable,
    p.is_fragile,
    p.requires_refrigeration,
    p.minimum_age,
    p.min_stock,
    p.max_stock,
    p.reorder_days,
    p.product_status,
    p.launch_date,
    p.discontinued_date,
    p.created_at,
    p.updated_at,
    p.deleted_at,
    p.keywords,
    p.rating_avg,
    p.rating_count
FROM core.products AS p
LEFT JOIN core.suppliers AS s
    ON s.supplier_id = p.supplier_id
WHERE
    p.updated_at <= ?
    AND
    (
        p.updated_at > ?
        OR (p.updated_at = ? AND p.product_id > ?)
    )
ORDER BY
    p.updated_at ASC,
    p.product_id ASC;
