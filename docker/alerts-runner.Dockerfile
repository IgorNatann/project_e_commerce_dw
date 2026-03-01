FROM python:3.11-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

# ODBC Driver 18 para conectividade pyodbc -> SQL Server
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl gnupg2 ca-certificates unixodbc tzdata \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && rm -rf /var/lib/apt/lists/*

COPY scripts/alerts/requirements.txt /tmp/requirements-alerts.txt
RUN pip install -r /tmp/requirements-alerts.txt

COPY scripts/alerts /app/scripts/alerts
RUN useradd --uid 10001 --create-home --shell /bin/bash appuser \
    && mkdir -p /var/lib/etl-alerts \
    && chown -R appuser:appuser /app /var/lib/etl-alerts

USER appuser

CMD ["python", "scripts/alerts/check_and_alert.py"]
