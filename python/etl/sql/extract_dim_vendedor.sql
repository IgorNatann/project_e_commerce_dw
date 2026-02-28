SELECT TOP ({batch_size})
    s.seller_id,
    s.seller_code,
    s.seller_name,
    s.team_id,
    s.manager_seller_id,
    m.seller_name AS manager_name,
    s.home_state,
    s.home_city,
    s.monthly_goal_amount,
    s.hire_date,
    s.seller_status,
    s.created_at,
    s.updated_at,
    s.deleted_at,
    t.team_name,
    t.team_type,
    t.team_category,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM core.sellers AS child
            WHERE child.manager_seller_id = s.seller_id
              AND child.deleted_at IS NULL
        ) THEN 1
        ELSE 0
    END AS is_team_leader
FROM core.sellers AS s
LEFT JOIN core.teams AS t
    ON t.team_id = s.team_id
LEFT JOIN core.sellers AS m
    ON m.seller_id = s.manager_seller_id
WHERE
    s.updated_at <= ?
    AND
    (
        s.updated_at > ?
        OR (s.updated_at = ? AND s.seller_id > ?)
    )
ORDER BY
    s.updated_at ASC,
    s.seller_id ASC;
