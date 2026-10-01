from django.core.cache import cache
import requests
from django.conf import settings

def get_shiprocket_token():
    token = cache.get('shiprocket_token')

    # 👉 If token exists, return it
    if token:
        return token

    # 👉 Else generate new token
    url = f"{settings.SHIPROCKET_BASE_URL}/auth/login"

    payload = {
        "email": settings.SHIPROCKET_EMAIL,
        "password": settings.SHIPROCKET_PASSWORD
    }

    response = requests.post(url, json=payload)
    data = response.json()

    token = data['token']

    # 👉 Save token in cache (for 23 hours)
    cache.set('shiprocket_token', token, timeout=60*60*23)

    return token

def calculate_shipping_rate(payload):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/courier/serviceability/"

    headers = {
        "Authorization": f"Bearer {token}"
    }

    # 👉 directly dynamic params pass कर
    response = requests.get(url, headers=headers, params=payload)

    return response.json()

def select_recommended_courier(response):
    data = response.get('data', {})
    couriers = data.get('available_courier_companies', [])

    if not couriers:
        return None

    recommended_id = data.get('recommended_courier_company_id')

    # 👉 1st priority: Shiprocket recommended
    for courier in couriers:
        if courier.get('courier_company_id') == recommended_id:
            return courier

    # 👉 fallback: cheapest
    return min(couriers, key=lambda x: x.get('rate', 9999))

def create_order(order_payload):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/orders/create/adhoc"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    response = requests.post(url, headers=headers, json=order_payload)

    return response.json()

# 🚚 ASSIGN COURIER
def assign_courier(shipment_id, courier_id):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/courier/assign/awb"

    headers = {
        "Authorization": f"Bearer {token}"
    }

    payload = {
        "shipment_id": shipment_id,
        "courier_id": courier_id
    }

    response = requests.post(url, headers=headers, json=payload)

    return response.json()

# 📅 SCHEDULE PICKUP
def schedule_pickup(shipment_id):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/courier/generate/pickup"

    headers = {
        "Authorization": f"Bearer {token}"
    }

    payload = {
        "shipment_id": [shipment_id]
    }

    response = requests.post(url, headers=headers, json=payload)

    return response.json()

# 🏷️ GENERATE LABEL
def generate_label(shipment_id):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/courier/generate/label"

    headers = {
        "Authorization": f"Bearer {token}"
    }

    payload = {
        "shipment_id": [shipment_id]
    }

    response = requests.post(url, headers=headers, json=payload)

    return response.json()

# 📍 TRACK ORDER
def track_order(shipment_id):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/courier/track/shipment/{shipment_id}"

    headers = {
        "Authorization": f"Bearer {token}"
    }

    response = requests.get(url, headers=headers)

    return response.json()

def cancel_order(shiprocket_order_id):
    token = get_shiprocket_token()

    url = f"{settings.SHIPROCKET_BASE_URL}/orders/cancel"

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    payload = {
        "ids": [shiprocket_order_id]   # ✅ NO int() conversion
    }

    response = requests.post(url, headers=headers, json=payload)

    print("Cancel Response:", response.text)

    return response.json()