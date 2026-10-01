import re


def parse_number(value, default=10):
    if not value:
        return float(default)

    match = re.findall(r"\d+\.?\d*", str(value))
    if not match:
        return float(default)

    return float(match[0])


def parse_weight(weight_str):
    import re

    if not weight_str:
        return 1

    value = float(re.findall(r"\d+\.?\d*", str(weight_str))[0])

    # detect unit properly
    if "kg" in str(weight_str).lower():
        return round(value, 2)

    if "g" in str(weight_str).lower():
        return round(value / 1000, 2)

    return round(value, 2)