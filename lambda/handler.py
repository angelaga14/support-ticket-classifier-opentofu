"""
URL Shortener Lambda handler.
Maneja dos endpoints:
  POST /shorten  -> guarda URL larga, regresa codigo corto
  GET  /{code}   -> busca codigo, regresa redirect (302) a la URL original
                    Tambien loggea la visita a S3.
"""

import json
import os
import string
import secrets
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

# Clientes inicializados fuera del handler para reuso entre invocaciones
# (cold start optimization).
ddb = boto3.resource("dynamodb")
s3 = boto3.client("s3")

TABLE_NAME = os.environ["TABLE_NAME"]
LOG_BUCKET = os.environ["LOG_BUCKET"]
CODE_LENGTH = 8

table = ddb.Table(TABLE_NAME)


def _generate_code(length: int = CODE_LENGTH) -> str:
    """Genera un codigo random alfanumerico."""
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def _response(status_code: int, body: dict, headers: dict = None) -> dict:
    """Construye una respuesta para API Gateway HTTP API."""
    return {
        "statusCode": status_code,
        "headers": headers or {"Content-Type": "application/json"},
        "body": json.dumps(body) if isinstance(body, dict) else body,
    }


def lambda_handler(event, context):
    """
    Punto de entrada. Distingue entre POST /shorten y GET /{code}
    usando el routeKey de API Gateway HTTP API.
    """
    print(f"Event: {json.dumps(event)}")

    route_key = event.get("routeKey", "")

    if route_key == "POST /shorten":
        return handle_shorten(event)
    elif route_key == "GET /{code}":
        return handle_redirect(event)
    else:
        return _response(404, {"error": f"Route not found: {route_key}"})


def handle_shorten(event):
    """Crea un codigo corto y lo guarda en DynamoDB."""
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON body"})

    url = body.get("url")
    if not url or not url.startswith(("http://", "https://")):
        return _response(400, {"error": "Field 'url' must start with http:// or https://"})

    code = _generate_code()

    try:
        table.put_item(
            Item={
                "code": code,
                "url": url,
                "created_at": datetime.now(timezone.utc).isoformat(),
                "hits": 0,
            },
            # Si por casualidad el codigo ya existe, falla. En produccion
            # se haria un retry con un codigo nuevo. Para la demo, OK.
            ConditionExpression="attribute_not_exists(code)",
        )
    except ClientError as e:
        return _response(500, {"error": f"Could not save: {e.response['Error']['Code']}"})

    # Construye la URL corta a partir del dominio del API Gateway
    domain = event.get("requestContext", {}).get("domainName", "unknown")
    stage = event.get("requestContext", {}).get("stage", "")
    short_url = f"https://{domain}/{code}" if not stage or stage == "$default" else f"https://{domain}/{stage}/{code}"

    return _response(201, {
        "code": code,
        "short_url": short_url,
        "original_url": url,
    })


def handle_redirect(event):
    """Busca el codigo, incrementa contador y regresa redirect."""
    code = event.get("pathParameters", {}).get("code", "")
    if not code:
        return _response(400, {"error": "Code missing"})

    try:
        result = table.get_item(Key={"code": code})
    except ClientError as e:
        return _response(500, {"error": f"DDB error: {e.response['Error']['Code']}"})

    item = result.get("Item")
    if not item:
        return _response(404, {"error": "Code not found"})

    # Incrementa hits de forma atomica
    try:
        table.update_item(
            Key={"code": code},
            UpdateExpression="ADD hits :one",
            ExpressionAttributeValues={":one": 1},
        )
    except ClientError:
        # No es critico si falla, seguimos con el redirect
        pass

    # Loggea la visita a S3 (best-effort)
    _log_visit(event, code, item["url"])

    return _response(302, "", headers={"Location": item["url"]})


def _log_visit(event, code: str, url: str):
    """Escribe un log de visita a S3. Best-effort, no falla el redirect si no puede."""
    try:
        ts = datetime.now(timezone.utc)
        log_entry = {
            "timestamp": ts.isoformat(),
            "code": code,
            "url": url,
            "source_ip": event.get("requestContext", {}).get("http", {}).get("sourceIp", "unknown"),
            "user_agent": event.get("headers", {}).get("user-agent", "unknown"),
        }
        # Particionado por dia para que sea Athena-friendly
        key = f"logs/dt={ts.strftime('%Y-%m-%d')}/{ts.strftime('%H%M%S')}-{code}.json"
        s3.put_object(
            Bucket=LOG_BUCKET,
            Key=key,
            Body=json.dumps(log_entry).encode("utf-8"),
            ContentType="application/json",
        )
    except Exception as e:
        print(f"Failed to log visit: {e}")
