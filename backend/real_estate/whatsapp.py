import requests
from django.conf import settings


def send_whatsapp_meeting_message(
    customer_phone,
    customer_name,
    property_name,
    meeting_date,
    meeting_time,
    meeting_location
):
    """
    Send property meeting scheduled WhatsApp message using WATI.
    """

    # ==================================================
    # 1. Customer Mobile Number
    # ==================================================

    customer_phone = (
        str(customer_phone)
        .replace("+", "")
        .replace(" ", "")
        .replace("-", "")
    )

    # India number
    if customer_phone.startswith("0"):
        customer_phone = "91" + customer_phone[1:]

    elif len(customer_phone) == 10:
        customer_phone = "91" + customer_phone

    # ==================================================
    # 2. WATI API URL
    # ==================================================

    url = (
        f"{settings.WATI_API_URL}"
        f"/api/v1/sendTemplateMessage"
    )

    # ==================================================
    # 3. Headers
    # ==================================================

    headers = {
        "Authorization": f"Bearer {settings.WATI_ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }

    # ==================================================
    # 4. Template Parameters
    # ==================================================

    payload = {
        "template_name": "property_meeting_schedule",
        "broadcast_name": "property_meeting_schedule",
        "parameters": [
            {
                "name": "1",
                "value": str(customer_name or "")
            },
            {
                "name": "2",
                "value": str(property_name or "")
            },
            {
                "name": "3",
                "value": str(meeting_date)
            },
            {
                "name": "4",
                "value": str(meeting_time)
            },
            {
                "name": "5",
                "value": str(
                    meeting_location or "Property Site"
                )
            }
        ]
    }

    # ==================================================
    # 5. Send WATI Message
    # ==================================================

    try:

        response = requests.post(
            f"{url}?whatsappNumber={customer_phone}",
            headers=headers,
            json=payload,
            timeout=20
        )

        try:
            response_data = response.json()
        except ValueError:
            response_data = {
                "raw_response": response.text
            }

        return {
            "success": response.ok,
            "status_code": response.status_code,
            "response": response_data
        }

    except requests.RequestException as e:

        return {
            "success": False,
            "status_code": None,
            "response": None,
            "error": str(e)
        }