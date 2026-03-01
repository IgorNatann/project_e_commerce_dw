# Alertas Externos (Dia 5)

Runner para notificacao externa de eventos ETL:

- falha de pipeline (`status=failed`);
- atraso de SLA por watermark;
- ausencia de execucao recente;
- falha recorrente na janela de 7 dias.

Implementacao atual: `Discord Webhook`.

## Arquivos

- `scripts/alerts/check_and_alert.py`
- `scripts/alerts/requirements.txt`

## Variaveis de ambiente

- `ALERT_ENABLED` (`true|false`)
- `ALERT_PROVIDER` (default: `discord`)
- `ALERT_DISCORD_WEBHOOK_URL` (obrigatoria para envio real)
- `ALERT_CHECK_INTERVAL_SECONDS` (default: `300`)
- `ALERT_COOLDOWN_MINUTES` (default: `30`)
- `ALERT_SLA_WATERMARK_DELAY_MINUTES` (default: `120`)
- `ALERT_SLA_NO_RUN_HOURS` (default: `24`)
- `ALERT_FAIL_RATE_THRESHOLD` (default: `0.30`)
- `ALERT_FAIL_RATE_MIN_RUNS` (default: `3`)
- `ALERT_TIMEZONE` (default: `America/Sao_Paulo`)
- `ALERT_STATE_FILE` (default: `/var/lib/etl-alerts/state.json`)
- `ALERT_RUN_ONCE` (default: `false`)

Conexao SQL usa as variaveis do monitor ETL:

- `ETL_SQL_DRIVER`
- `ETL_SQL_SERVER`
- `ETL_SQL_PORT`
- `ETL_DW_DB`
- `ETL_SQL_USER`
- `ETL_SQL_PASSWORD`

## Execucao local (one-shot)

```powershell
$env:ALERT_ENABLED="true"
$env:ALERT_PROVIDER="discord"
$env:ALERT_DISCORD_WEBHOOK_URL="<webhook>"
$env:ALERT_RUN_ONCE="true"
python scripts/alerts/check_and_alert.py
```

## Fallback MVP

Se `ALERT_ENABLED=false` ou webhook nao configurado, o runner continua executando e registra logs sem interromper a stack.
