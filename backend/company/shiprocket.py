import requests
import re

from django.conf import settings


SHIPROCKET_BASE_URL = (
    "https://apiv2.shiprocket.in/v1/external"
)


def get_shiprocket_token():

    url = f"{SHIPROCKET_BASE_URL}/auth/login"

    payload = {
        "email": settings.SHIPROCKET_EMAIL,
        "password": settings.SHIPROCKET_PASSWORD,
    }

    response = requests.post(
        url,
        json=payload,
        timeout=30,
    )

    if response.status_code != 200:
        raise Exception(
            f"Shiprocket login failed: "
            f"{response.status_code} - {response.text}"
        )

    data = response.json()

    token = data.get("token")

    if not token:
        raise Exception(
            f"Shiprocket token not received: {data}"
        )

    return token


def generate_pickup_location_name(company):

    name = company.name.strip()

    name = re.sub(
        r"[^A-Za-z0-9]",
        "",
        name
    )

    name = f"{name}{company.id}"

    return name[:36]


def create_company_pickup_location(company):

    token = get_shiprocket_token()

    pickup_location = generate_pickup_location_name(company)

    # ==================================================
    # CHECK EXISTING PICKUP LOCATION
    # ==================================================

    existing_url = (
        f"{SHIPROCKET_BASE_URL}"
        "/settings/company/pickup"
    )

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }

    existing_response = requests.get(
        existing_url,
        headers=headers,
        timeout=30,
    )

    if existing_response.status_code != 200:
        raise Exception(
            "Failed to fetch Shiprocket pickup locations: "
            f"{existing_response.status_code} - "
            f"{existing_response.text}"
        )

    existing_data = existing_response.json()

    # Shiprocket response structure can contain data in different
    # fields depending on API response.
    pickup_locations = (
        existing_data
        .get("data", {})
        .get("shipping_address", [])
    )

    # ==================================================
    # DUPLICATE CHECK
    # ==================================================

    for location in pickup_locations:

        existing_code = (
            location.get("pickup_code")
            or location.get("pickup_location")
            or location.get("name")
        )

        if existing_code == pickup_location:

            return {
                "success": True,
                "already_exists": True,
                "pickup_location": pickup_location,
                "pickup_id": location.get("id"),
                "response": location,
            }

    # ==================================================
    # ADDRESS
    # ==================================================

    address = (
        company.address.strip()
        if company.address
        else ""
    )

    if len(address) < 10:

        raise Exception(
            "Company pickup address is invalid. "
            "Address must contain a proper house/flat/road address."
        )

    # ==================================================
    # ADDRESS 2
    # ==================================================

    address_2_parts = [
        company.village,
        company.taluka,
        company.district,
    ]

    address_2_parts = [
        str(value).strip()
        for value in address_2_parts
        if value
    ]

    address_2 = ", ".join(address_2_parts)

    # ==================================================
    # CITY
    # ==================================================

    city = (
        company.district
        or company.taluka
        or company.village
        or ""
    )

    # ==================================================
    # PAYLOAD
    # ==================================================

    payload = {
        "pickup_location": pickup_location,
        "email": company.email,
        "phone": company.phone_number,
        "name": (
            company.owner_name
            or company.name
        ),
        "address": address,
        "address_2": address_2,
        "city": city,
        "state": company.state or "",
        "country": "India",
        "pin_code": company.pincode,
    }

    # ==================================================
    # CREATE PICKUP LOCATION
    # ==================================================

    url = (
        f"{SHIPROCKET_BASE_URL}"
        "/settings/company/addpickup"
    )

    response = requests.post(
        url,
        json=payload,
        headers=headers,
        timeout=30,
    )

    if response.status_code not in [200, 201]:

        raise Exception(
            "Shiprocket pickup location creation failed: "
            f"{response.status_code} - "
            f"{response.text}"
        )

    data = response.json()

    return {
        "success": True,
        "already_exists": False,
        "pickup_location": pickup_location,
        "response": data,
    }    
    
def get_shiprocket_pickup_locations():
    """
    Fetch all pickup locations registered in the Shiprocket account.
    """
    token = get_shiprocket_token()

    url = f"{SHIPROCKET_BASE_URL}/settings/company/pickup"

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}",
    }

    response = requests.get(
        url,
        headers=headers,
        timeout=30,
    )

    if response.status_code != 200:
        raise Exception(
            "Failed to fetch Shiprocket pickup locations: "
            f"{response.status_code} - {response.text}"
        )

    return response.json()
