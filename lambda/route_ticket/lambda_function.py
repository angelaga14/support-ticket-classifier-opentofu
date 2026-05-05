import json
import os
import boto3

s3 = boto3.client("s3")

def lambda_handler(event, context):
    bucket = os.environ["BUCKET_NAME"]

    ticket_id = event.get("ticket_id", "unknown-ticket")
    severity = event.get("severity", "invalid")

    key = f"{severity}/{ticket_id}.json"

    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(event),
        ContentType="application/json"
    )

    event["s3_bucket"] = bucket
    event["s3_key"] = key

    return event