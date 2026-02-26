UPDATE ctl.etl_control
   SET watermark_updated_at = ?,
       watermark_id = ?,
       last_run_id = ?,
       last_status = ?,
       last_success_at = CASE WHEN ? = 'success' THEN SYSUTCDATETIME() ELSE last_success_at END,
       updated_at = SYSUTCDATETIME()
 WHERE entity_name = ?;
