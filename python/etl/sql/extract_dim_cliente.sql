SELECT TOP ({batch_size})
    c.customer_id,
    c.full_name,
    c.email,
    c.phone,
    c.document_number,
    c.birth_date,
    c.gender,
    c.customer_type,
    c.segment,
    c.credit_score,
    c.value_category,
    c.address_line,
    c.district,
    c.city,
    c.state,
    c.country,
    c.zip_code,
    c.first_signup_date,
    c.last_purchase_date,
    c.is_active,
    c.accepts_email_marketing,
    c.is_vip,
    c.created_at,
    c.updated_at,
    c.deleted_at
FROM core.customers AS c
WHERE
    c.updated_at <= ?
    AND
    (
        c.updated_at > ?
        OR (c.updated_at = ? AND c.customer_id > ?)
    )
ORDER BY
    c.updated_at ASC,
    c.customer_id ASC;
