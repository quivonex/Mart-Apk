
import requests
from django.conf import settings


def send_bazaar_enquiry_message(
    owner_phone,
    owner_name,
    listing_title,
    listing_price,
    enquiry_user_name,
    enquiry_user_phone,
    enquiry_message
):
    """
    Send Bazaar enquiry WhatsApp message to listing owner using WATI.
    """

    # ==================================================
    # 1. Owner Mobile Number
    # ==================================================

    owner_phone = (
        str(owner_phone)
        .replace("+", "")
        .replace(" ", "")
        .replace("-", "")
    )

    # India number
    if owner_phone.startswith("0"):
        owner_phone = "91" + owner_phone[1:]

    elif len(owner_phone) == 10:
        owner_phone = "91" + owner_phone

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
        "template_name": "bazaar_enquiry",
        "broadcast_name": "bazaar_enquiry",

        "parameters": [
            {
                "name": "1",
                "value": str(owner_name or "")
            },
            {
                "name": "2",
                "value": str(listing_title or "")
            },
            {
                "name": "3",
                "value": f"₹{listing_price}"
            },
            {
                "name": "4",
                "value": str(enquiry_user_name or "")
            },
            {
                "name": "5",
                "value": str(enquiry_user_phone or "")
            },
            {
                "name": "6",
                "value": str(enquiry_message or "")
            }
        ]
    }

    # ==================================================
    # 5. Send WATI Message
    # ==================================================

    try:

        response = requests.post(
            f"{url}?whatsappNumber={owner_phone}",
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

