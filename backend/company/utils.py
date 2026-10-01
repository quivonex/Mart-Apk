import requests
from django.conf import settings


def send_upi_payout(amount, upi_id, name):

    url = "https://api.razorpay.com/v1/payouts"

    payload = {
        "account_number": settings.RAZORPAYX_ACCOUNT_NUMBER,
        "fund_account": {
            "account_type": "vpa",
            "vpa": {
                "address": upi_id
            },
            "contact": {
                "name": name,
                "type": "vendor"
            }
        },
        "amount": int(amount * 100),
        "currency": "INR",
        "mode": "UPI",
        "purpose": "payout",
        "queue_if_low_balance": True,
        "reference_id": "ref_001",
        "narration": "Commission Payment"
    }

    response = requests.post(
        url,
        auth=(
            settings.RAZORPAY_KEY_ID,
            settings.RAZORPAY_KEY_SECRET
        ),
        json=payload
    )

    print(response.json())

    data = response.json()

    return {
        "fund_account_id": data.get("fund_account_id"),
        "payout_id": data.get("id"),
        "status": data.get("status")
    }