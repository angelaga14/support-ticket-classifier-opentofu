def lambda_handler(event, context):
    errors = []

    score = event.get("priority_score")
    description = event.get("description", "")

    if not isinstance(score, (int, float)):
        errors.append("priority_score must be numeric")
    elif score < 0 or score > 100:
        errors.append("priority_score must be between 0 and 100")

    if not isinstance(description, str) or description.strip() == "":
        errors.append("description must not be empty")

    event["is_valid"] = len(errors) == 0
    event["validation_errors"] = errors

    return event