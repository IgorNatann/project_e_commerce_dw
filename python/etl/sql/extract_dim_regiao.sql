SELECT TOP ({batch_size})
    r.region_id,
    r.region_code,
    r.country,
    r.region_name,
    r.state,
    r.state_name,
    r.city,
    r.ibge_code,
    r.is_active,
    r.created_at,
    r.updated_at,
    r.deleted_at
FROM core.regions AS r
WHERE
    r.updated_at <= ?
    AND
    (
        r.updated_at > ?
        OR (r.updated_at = ? AND r.region_id > ?)
    )
ORDER BY
    r.updated_at ASC,
    r.region_id ASC;
