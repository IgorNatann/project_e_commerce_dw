SELECT TOP ({batch_size})
    t.team_id,
    t.team_code,
    t.team_name,
    t.team_type,
    t.team_category,
    t.region_id,
    t.is_active,
    t.created_at,
    t.updated_at,
    t.deleted_at,
    r.region_name,
    r.state AS region_state,
    r.city AS region_city,
    agg.active_sellers_count,
    agg.total_sellers_count,
    agg.monthly_goal_sum,
    leader.seller_id AS leader_seller_id,
    leader.seller_name AS leader_name
FROM core.teams AS t
LEFT JOIN core.regions AS r
    ON r.region_id = t.region_id
OUTER APPLY
(
    SELECT
        SUM(CASE WHEN s.deleted_at IS NULL AND s.seller_status = 'Ativo' THEN 1 ELSE 0 END) AS active_sellers_count,
        COUNT(*) AS total_sellers_count,
        SUM(CASE WHEN s.monthly_goal_amount IS NOT NULL AND s.monthly_goal_amount >= 0 THEN s.monthly_goal_amount ELSE 0 END) AS monthly_goal_sum
    FROM core.sellers AS s
    WHERE s.team_id = t.team_id
) AS agg
OUTER APPLY
(
    SELECT TOP 1
        s2.seller_id,
        s2.seller_name
    FROM core.sellers AS s2
    WHERE s2.team_id = t.team_id
      AND s2.deleted_at IS NULL
    ORDER BY
        CASE WHEN s2.manager_seller_id IS NULL THEN 0 ELSE 1 END,
        s2.seller_id ASC
) AS leader
WHERE
    t.updated_at <= ?
    AND
    (
        t.updated_at > ?
        OR (t.updated_at = ? AND t.team_id > ?)
    )
ORDER BY
    t.updated_at ASC,
    t.team_id ASC;
