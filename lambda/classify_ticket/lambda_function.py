def lambda_handler(event, context):
    if not event.get("is_valid"):
        event["severity"] = "invalid"
        return event

    score = event.get("priority_score", 0)
    description = event.get("description", "").lower()

    urgent_words = ["urgent", "down", "not working", "unresponsive", "error"]

    has_urgent_word = any(word in description for word in urgent_words)

    if score >= 80 or has_urgent_word:
        severity = "urgent"
    elif score >= 40:
        severity = "normal"
    else:
        severity = "low"

    event["severity"] = severity

    return event