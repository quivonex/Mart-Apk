import requests
from django.conf import settings


class ShiprocketService:
    BASE_URL = "https://apiv2.shiprocket.in/v1/external"

    # ==========================================
    # Get Authentication Token
    # ==========================================
    @staticmethod
    def get_token():
        url = f"{ShiprocketService.BASE_URL}/auth/login"

        payload = {
            "email": settings.SHIPROCKET_EMAIL,
            "password": settings.SHIPROCKET_PASSWORD,
        }

        response = requests.post(url, json=payload)

        print("Status Code:", response.status_code)
        print("Response:", response.text)

        if response.status_code != 200:
            raise Exception(f"Shiprocket Login Failed: {response.text}")

        return response.json()["token"]

    # ==========================================
    # Common Headers
    # ==========================================
    @staticmethod
    def get_headers():
        token = ShiprocketService.get_token()

        return {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }

    # ==========================================
    # Check Courier Serviceability
    # ==========================================
    @staticmethod
    def check_serviceability(
        pickup_pincode,
        delivery_pincode,
        weight,
        length,
        breadth,
        height,
        cod=False,
    ):

        url = f"{ShiprocketService.BASE_URL}/courier/serviceability/"

        params = {
            "pickup_postcode": pickup_pincode,
            "delivery_postcode": delivery_pincode,
            "cod": int(cod),
            "weight": weight,
            "length": length,
            "breadth": breadth,
            "height": height,
        }

        response = requests.get(
            url,
            headers=ShiprocketService.get_headers(),
            params=params,
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Create Order
    # ==========================================
    @staticmethod
    def create_order(payload):

        url = f"{ShiprocketService.BASE_URL}/orders/create/adhoc"

        try:

            response = requests.post(
                url,
                json=payload,
                headers=ShiprocketService.get_headers(),
            )

            print("========== Shiprocket Create Order Response ==========")
            print("Status:", response.status_code)
            print("Body:", response.text)


            if response.status_code not in [200, 201]:

                return {
                    "success": False,
                    "status_code": response.status_code,
                    "error": response.text
                }


            return response.json()


        except Exception as e:

            return {
                "success": False,
                "error": str(e)
            }
    # ==========================================
    # Assign AWB
    # ==========================================
    @staticmethod
    def assign_awb(
        shipment_id,
        courier_company_id=None
    ):

        url = f"{ShiprocketService.BASE_URL}/courier/assign/awb"

        # --------------------------------
        # Payload
        # --------------------------------

        payload = {
            "shipment_id": int(shipment_id)
        }

        if courier_company_id is not None:

            payload["courier_id"] = int(
                courier_company_id
            )

        # --------------------------------
        # Headers
        # --------------------------------

        headers = ShiprocketService.get_headers()

        print("========================================")
        print("        ASSIGN AWB REQUEST")
        print("========================================")
        print("URL     :", url)
        print("Payload :", payload)
        print("Headers :", headers)
        print("========================================")

        # --------------------------------
        # Shiprocket API
        # --------------------------------

        response = requests.post(
            url,
            json=payload,
            headers=headers,
            timeout=30
        )

        print("========================================")
        print("        ASSIGN AWB RESPONSE")
        print("========================================")
        print("Status   :", response.status_code)
        print("Response :", response.text)
        print("========================================")

        # --------------------------------
        # JSON Response
        # --------------------------------

        try:

            return response.json()

        except ValueError:

            return {
                "awb_assign_status": 0,
                "message": "Invalid response from Shiprocket.",
                "http_status": response.status_code,
                "raw_response": response.text
            }

        # ==========================================
        # Generate Label
        # ==========================================
    @staticmethod
    def generate_label(shipment_id):

            url = f"{ShiprocketService.BASE_URL}/courier/generate/label"

            payload = {
                "shipment_id": [int(shipment_id)],
            }

            response = requests.post(
                url,
                json=payload,
                headers=ShiprocketService.get_headers(),
            )

            response.raise_for_status()

            return response.json()

    # ==========================================
    # Request Pickup
    # ==========================================
    @staticmethod
    def request_pickup(shipment_id):

        url = f"{ShiprocketService.BASE_URL}/courier/generate/pickup"

        payload = {
            "shipment_id": [int(shipment_id)],
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Track Shipment
    # ==========================================
    @staticmethod
    def track_shipment(shipment_id):

        url = (
            f"{ShiprocketService.BASE_URL}"
            f"/courier/track/shipment/{shipment_id}"
        )

        response = requests.get(
            url,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Generate Manifest
    # ==========================================
    @staticmethod
    def generate_manifest(shipment_id):

        url = f"{ShiprocketService.BASE_URL}/manifests/generate"

        payload = {
            "shipment_id": [int(shipment_id)],
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Cancel Order
    # ==========================================
    @staticmethod
    def cancel_order(order_id):

        url = f"{ShiprocketService.BASE_URL}/orders/cancel"

        payload = {
            "ids": [int(order_id)],
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Cancel Pickup
    # ==========================================
    @staticmethod
    def cancel_shipment_by_awb(awb):

        url = f"{ShiprocketService.BASE_URL}/orders/cancel/shipment/awbs"

        payload = {
            "awbs": [str(awb)]
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
            timeout=30
        )

        print("Cancel Shipment Status:", response.status_code)
        print("Cancel Shipment Response:", response.text)

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Download Label
    # ==========================================
    @staticmethod
    def download_label(shipment_id):

        token = ShiprocketService.get_token()

        url = "https://apiv2.shiprocket.in/v1/external/courier/generate/label"

        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}"
        }

        payload = {
            "shipment_id": [int(shipment_id)]
        }

        print("========== SHIPROCKET GENERATE LABEL ==========")
        print("URL      :", url)
        print("Payload  :", payload)
        print("===============================================")

        response = requests.post(
            url,
            headers=headers,
            json=payload
        )

        print("Status Code :", response.status_code)
        print("Response     :", response.text)

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Download Invoice
    # ==========================================
    @staticmethod
    def download_invoice(order_id):

        url = f"{ShiprocketService.BASE_URL}/orders/print/invoice"

        payload = {
            "ids": [int(order_id)],
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()

    # ==========================================
    # Download Manifest
    # ==========================================
    @staticmethod
    def download_manifest(shipment_id):

        url = f"{ShiprocketService.BASE_URL}/manifests/print"

        payload = {
            "shipment_id": [int(shipment_id)],
        }

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
        )

        response.raise_for_status()

        return response.json()
   
    
    @staticmethod
    def create_order(payload):

        url = (
            f"{ShiprocketService.BASE_URL}"
            "/orders/create/adhoc"
        )

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
            timeout=30
        )

        print("CREATE ORDER STATUS:", response.status_code)
        print("CREATE ORDER RESPONSE:", response.text)

        try:
            return response.json()
        except ValueError:
            return {
                "success": False,
                "status_code": response.status_code,
                "message": response.text
            }

    # =====================================================
    # CREATE RETURN SHIPMENT
    # =====================================================

    @staticmethod
    def create_return_shipment(payload):

        url = (
            f"{ShiprocketService.BASE_URL}"
            "/shipments/create/return-shipment"
        )

        headers = ShiprocketService.get_headers()

        print("========================================")
        print("CREATE RETURN SHIPMENT")
        print("========================================")
        print("URL:", url)
        print("PAYLOAD:", payload)
        print("========================================")

        try:

            response = requests.post(
                url,
                json=payload,
                headers=headers,
                timeout=30
            )

            print("========================================")
            print("RETURN SHIPMENT RESPONSE")
            print("========================================")
            print("STATUS:", response.status_code)
            print("BODY:", response.text)
            print("========================================")

            try:

                data = response.json()

            except ValueError:

                return {
                    "success": False,
                    "status_code": response.status_code,
                    "message": "Invalid response from Shiprocket.",
                    "raw_response": response.text
                }

            if response.status_code not in [200, 201]:

                return {
                    "success": False,
                    "status_code": response.status_code,
                    "error": data
                }

            return {
                "success": True,
                "status_code": response.status_code,
                "data": data
            }

        except requests.exceptions.RequestException as e:

            print("RETURN SHIPMENT REQUEST ERROR:", str(e))

            return {
                "success": False,
                "message": str(e)
            }

        except Exception as e:

            print("RETURN SHIPMENT ERROR:", str(e))

            return {
                "success": False,
                "message": str(e)
            }


# ==========================================
# Assign AWB For Return
# ==========================================
@staticmethod
def assign_return_awb(
    shipment_id,
    courier_id=None
):

    url = (
        f"{ShiprocketService.BASE_URL}"
        "/courier/assign/awb"
    )

    payload = {
        "shipment_id": int(shipment_id),
        "is_return": 1
    }

    if courier_id:

        payload["courier_id"] = int(
            courier_id
        )

    print("========================================")
    print("ASSIGN RETURN AWB")
    print("========================================")
    print("URL     :", url)
    print("Payload :", payload)
    print("========================================")

    try:

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
            timeout=30
        )

        print("Status   :", response.status_code)
        print("Response :", response.text)

        try:
            data = response.json()

        except ValueError:

            return {
                "success": False,
                "status_code": response.status_code,
                "message": response.text
            }

        if response.status_code not in [200, 201]:

            return {
                "success": False,
                "status_code": response.status_code,
                "error": data
            }

        return {
            "success": True,
            "status_code": response.status_code,
            "data": data
        }

    except Exception as e:

        return {
            "success": False,
            "error": str(e)
        }


# ==========================================
# Return Pickup Request
# ==========================================
@staticmethod
def request_return_pickup(shipment_id):

    url = (
        f"{ShiprocketService.BASE_URL}"
        "/courier/generate/pickup"
    )

    payload = {
        "shipment_id": [int(shipment_id)]
    }

    print("========================================")
    print("RETURN PICKUP REQUEST")
    print("========================================")
    print("URL     :", url)
    print("Payload :", payload)
    print("========================================")

    try:

        response = requests.post(
            url,
            json=payload,
            headers=ShiprocketService.get_headers(),
            timeout=30
        )

        print("Status   :", response.status_code)
        print("Response :", response.text)

        try:
            data = response.json()

        except ValueError:

            return {
                "success": False,
                "status_code": response.status_code,
                "message": response.text
            }

        if response.status_code not in [200, 201]:

            return {
                "success": False,
                "status_code": response.status_code,
                "error": data
            }

        return {
            "success": True,
            "status_code": response.status_code,
            "data": data
        }

    except Exception as e:

        return {
            "success": False,
            "error": str(e)
        }


# ==========================================
# Track Return Shipment
# ==========================================
@staticmethod
def track_return_shipment(shipment_id):

    url = (
        f"{ShiprocketService.BASE_URL}"
        f"/courier/track/shipment/{shipment_id}"
    )

    try:

        response = requests.get(
            url,
            headers=ShiprocketService.get_headers(),
            timeout=30
        )

        print("========================================")
        print("TRACK RETURN SHIPMENT")
        print("========================================")
        print("URL      :", url)
        print("Status   :", response.status_code)
        print("Response :", response.text)
        print("========================================")

        try:
            data = response.json()

        except ValueError:

            return {
                "success": False,
                "status_code": response.status_code,
                "message": response.text
            }

        if response.status_code != 200:

            return {
                "success": False,
                "status_code": response.status_code,
                "error": data
            }

        return {
            "success": True,
            "status_code": response.status_code,
            "data": data
        }

    except Exception as e:

        return {
            "success": False,
            "error": str(e)
        }        