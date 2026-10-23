import re
import requests
from rest_framework.views import APIView 
from rest_framework.response import Response
from shiprocket.serializers import ShipmentListSerializer
from company.models import Company
from product.models import Product
from order.models import Address
from state.services.shiprocket import ShiprocketService, get_shipping_rates

from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated
from decimal import Decimal
import random
from .models import ShipOrder, ShipOrderItem
from .models import ReturnOrder
from django.db.models import Q

class ShippingRateAPIView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        # =====================================================
        # GET REQUEST DATA
        # =====================================================

        product_ids = request.data.get("product_ids")
        address_id = request.data.get("address_id")

        payment_method = request.data.get(
            "payment_method",
            "Prepaid"
        )

        # =====================================================
        # VALIDATE PRODUCT IDS
        # =====================================================

        if not product_ids:
            return Response(
                {
                    "status": False,
                    "message": "product_ids is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not isinstance(product_ids, list):
            return Response(
                {
                    "status": False,
                    "message": "product_ids must be an array."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(product_ids) == 0:
            return Response(
                {
                    "status": False,
                    "message": "At least one product_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # VALIDATE ADDRESS
        # =====================================================

        if not address_id:
            return Response(
                {
                    "status": False,
                    "message": "address_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET PRODUCTS + ADDRESS
        # =====================================================

        try:

            products = list(
                Product.objects
                .select_related("company")
                .filter(
                    id__in=product_ids,
                    is_active=True
                )
            )

            # =================================================
            # NO PRODUCTS
            # =================================================

            if not products:
                return Response(
                    {
                        "status": False,
                        "message": "No products found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # =================================================
            # CHECK MISSING PRODUCTS
            # =================================================

            found_ids = {
                product.id
                for product in products
            }

            missing_product_ids = [
                product_id
                for product_id in product_ids
                if product_id not in found_ids
            ]

            if missing_product_ids:
                return Response(
                    {
                        "status": False,
                        "message": "Some products were not found.",
                        "missing_product_ids": missing_product_ids
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # =================================================
            # GET ADDRESS
            # =================================================

            address = Address.objects.get(
                id=address_id
            )

        except Address.DoesNotExist:

            return Response(
                {
                    "status": False,
                    "message": "Address not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        except Exception as e:

            return Response(
                {
                    "status": False,
                    "message": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # SHIPPING CALCULATION
        # =====================================================

        try:

            # =================================================
            # COD
            # =================================================

            cod = (
                payment_method.lower()
                == "cod"
            )

            # =================================================
            # GROUP PRODUCTS BY COMPANY
            # =================================================

            company_products = {}

            for product in products:

                if not product.company:

                    return Response(
                        {
                            "status": False,
                            "message": (
                                f"Company not found for "
                                f"product {product.id}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                company_id = product.company.id

                if company_id not in company_products:

                    company_products[company_id] = {
                        "company": product.company,
                        "products": []
                    }

                company_products[
                    company_id
                ]["products"].append(product)

            # =================================================
            # FINAL RESPONSE DATA
            # =================================================

            companies_data = []

            total_shipping_charge = 0.0

            # =================================================
            # PROCESS EACH COMPANY
            # =================================================

            for company_id, company_data in company_products.items():

                company = company_data["company"]
                company_product_list = company_data["products"]

                # =============================================
                # PICKUP PINCODE
                # =============================================

                if not company.pincode:

                    return Response(
                        {
                            "status": False,
                            "message": (
                                f"Pickup pincode missing "
                                f"for company {company.name}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                # =============================================
                # CALCULATE TOTAL WEIGHT & DIMENSIONS
                # =============================================

                total_weight = 0.0
                total_length = 0.0
                total_breadth = 0.0
                total_height = 0.0

                company_products_data = []

                for product in company_product_list:

                    weight = float(
                        product.weight or 0
                    )

                    length = float(
                        product.length or 0
                    )

                    breadth = float(
                        product.width or 0
                    )

                    height = float(
                        product.height or 0
                    )

                    total_weight += weight
                    total_length += length
                    total_breadth += breadth
                    total_height += height

                    company_products_data.append(
                        {
                            "product_id": product.id,

                            "product_name": product.name,

                            "weight": weight,

                            "length": length,

                            "breadth": breadth,

                            "height": height,
                        }
                    )

                # =============================================
                # WEIGHT VALIDATION
                # =============================================

                if total_weight <= 0:

                    return Response(
                        {
                            "status": False,
                            "message": (
                                f"Product weight must be greater "
                                f"than 0 for company "
                                f"{company.name}."
                            )
                        },
                        status=status.HTTP_400_BAD_REQUEST
                    )

                # =============================================
                # SHIPROCKET API
                # =============================================

                shiprocket_response = (
                    ShiprocketService.check_serviceability(

                        pickup_pincode=company.pincode,

                        delivery_pincode=address.pincode,

                        weight=total_weight,

                        length=total_length,

                        breadth=total_breadth,

                        height=total_height,

                        cod=cod,
                    )
                )

                # =============================================
                # AVAILABLE COURIERS
                # =============================================

                available_couriers = (
                    shiprocket_response
                    .get("data", {})
                    .get(
                        "available_courier_companies",
                        []
                    )
                )

                # =============================================
                # IMPORTANT:
                # ONLY SURFACE COURIERS
                # =============================================

                surface_couriers = [
                    courier
                    for courier in available_couriers
                    if courier.get("is_surface") is True
                ]

                courier_list = []

                company_shipping_charge = 0.0

                # =============================================
                # RECOMMENDED COURIER ID
                # =============================================

                recommended_courier_company_id = (
                    shiprocket_response
                    .get("data", {})
                    .get(
                        "recommended_courier_company_id"
                    )
                )

                # =============================================
                # COURIER LIST
                # ONLY SURFACE
                # =============================================

                for courier in surface_couriers:

                    freight_charge = float(
                        courier.get(
                            "freight_charge",
                            0
                        )
                    )

                    cod_charges = float(
                        courier.get(
                            "cod_charges",
                            0
                        )
                    )

                    # =========================================
                    # TOTAL CHARGE
                    # =========================================

                    total_charge = (
                        freight_charge + cod_charges
                        if cod
                        else freight_charge
                    )

                    courier_list.append(
                        {
                            "courier_company_id":
                                courier.get(
                                    "courier_company_id"
                                ),

                            "courier_name":
                                courier.get(
                                    "courier_name"
                                ),

                            "estimated_delivery_days":
                                courier.get(
                                    "estimated_delivery_days"
                                ),

                            "etd":
                                courier.get(
                                    "etd"
                                ),

                            "freight_charge":
                                freight_charge,

                            "cod_charges":
                                cod_charges,

                            "total_charge":
                                total_charge,

                            "rating":
                                courier.get(
                                    "rating"
                                ),

                            # Always TRUE because
                            # only surface courier
                            "is_surface": True,

                            "cod_available":
                                bool(
                                    courier.get(
                                        "cod"
                                    )
                                ),

                            "recommended":
                                bool(
                                    courier.get(
                                        "recommended_lt"
                                    )
                                ),

                            "pickup_available":
                                courier.get(
                                    "pickup_availability"
                                ),
                        }
                    )

                # =============================================
                # RECOMMENDED COURIER
                # =============================================

                recommended_courier = None

                if recommended_courier_company_id:

                    for courier in courier_list:

                        if (
                            courier[
                                "courier_company_id"
                            ]
                            ==
                            recommended_courier_company_id
                        ):

                            recommended_courier = courier

                            break

                # =============================================
                # FALLBACK FIRST SURFACE COURIER
                # =============================================

                if (
                    not recommended_courier
                    and courier_list
                ):

                    recommended_courier = courier_list[0]

                # =============================================
                # SHIPPING CHARGE
                # =============================================

                if recommended_courier:

                    company_shipping_charge = float(
                        recommended_courier.get(
                            "total_charge",
                            0
                        )
                    )

                total_shipping_charge += (
                    company_shipping_charge
                )

                # =============================================
                # COMPANY RESPONSE
                # =============================================

                companies_data.append(
                    {
                        "company_id":
                            company.id,

                        "company_name":
                            company.name,

                        "pickup_pincode":
                            company.pincode,

                        "delivery_pincode":
                            address.pincode,

                        "products":
                            company_products_data,

                        "shipment":
                            {
                                "total_weight":
                                    total_weight,

                                "length":
                                    total_length,

                                "breadth":
                                    total_breadth,

                                "height":
                                    total_height,
                            },

                        "recommended_courier_company_id":
                            (
                                recommended_courier[
                                    "courier_company_id"
                                ]
                                if recommended_courier
                                else None
                            ),

                        "recommended_courier":
                            recommended_courier,

                        "shipping_charge":
                            company_shipping_charge,

                        "total_couriers":
                            len(courier_list),

                        "couriers":
                            courier_list,
                    }
                )

            # =================================================
            # FINAL RESPONSE
            # =================================================

            return Response(
                {
                    "status": True,

                    "message":
                        "Surface shipping rates fetched successfully.",

                    "payment_method":
                        payment_method,

                    "cod":
                        cod,

                    "delivery_type":
                        "Surface",

                    "total_products":
                        len(products),

                    "total_companies":
                        len(companies_data),

                    "total_shipping_charge":
                        round(
                            total_shipping_charge,
                            2
                        ),

                    "companies":
                        companies_data,
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "status": False,
                    "message": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )
            

class OrderCourierRatesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        order_id = request.data.get("order_id")

        if not order_id:
            return Response(
                {
                    "success": False,
                    "message": "order_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            order = ShipOrder.objects.select_related(
                "product",
                "company",
                "address"
            ).get(
                id=order_id
            )

        except ShipOrder.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        try:

            product = order.product
            company = order.company
            address = order.address

            # ==========================================
            # Validate Pincodes
            # ==========================================

            if not company.pincode:
                return Response(
                    {
                        "success": False,
                        "message": "Company pickup pincode missing."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            if not address.pincode:
                return Response(
                    {
                        "success": False,
                        "message": "Customer delivery pincode missing."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # Product Details
            # ==========================================

            weight = float(
                product.weight or 0
            )

            length = float(
                product.length or 0
            )

            breadth = float(
                product.width or 0
            )

            height = float(
                product.height or 0
            )

            # Quantity
            total_weight = (
                weight * order.quantity
            )

            # ==========================================
            # Payment
            # ==========================================

            cod = (
                order.payment_method.upper()
                == "COD"
            )

            # ==========================================
            # Shiprocket Rates
            # ==========================================

            shiprocket_response = (
                ShiprocketService.check_serviceability(

                    pickup_pincode=company.pincode,

                    delivery_pincode=address.pincode,

                    weight=total_weight,

                    length=length,

                    breadth=breadth,

                    height=height,

                    cod=cod
                )
            )

            # ==========================================
            # Available Couriers
            # ==========================================

            available_couriers = (
                shiprocket_response
                .get("data", {})
                .get(
                    "available_courier_companies",
                    []
                )
            )

            courier_list = []

            for courier in available_couriers:

                freight_charge = float(
                    courier.get(
                        "freight_charge",
                        0
                    ) or 0
                )

                cod_charges = float(
                    courier.get(
                        "cod_charges",
                        0
                    ) or 0
                )

                # Final Rate
                if cod:
                    rate = (
                        freight_charge
                        +
                        cod_charges
                    )
                else:
                    rate = freight_charge

                courier_list.append(
                    {
                        "courier_id": courier.get(
                            "courier_company_id"
                        ),

                        "rate": round(
                            rate,
                            2
                        )
                    }
                )

            # ==========================================
            # No Courier
            # ==========================================

            if not courier_list:

                return Response(
                    {
                        "success": False,
                        "message": "No courier available."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==========================================
            # Final Response
            # ==========================================

            return Response(
                {
                    "success": True,
                    "data": courier_list
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )            
# import re

# from rest_framework.views import APIView
# from rest_framework.response import Response

# from .models import ShipOrder
# from product.models import Product
# from order.models import Address


# class ShippingRateAPIView(APIView):

#     def post(self, request):

#         product_id = request.data.get("product_id")
#         address_id = request.data.get("address_id")
#         payment_method = request.data.get("payment_method", "Prepaid")

#         try:
#             product = Product.objects.select_related("company").get(id=product_id)
#             company = product.company
#             address = Address.objects.get(id=address_id)

#         except Product.DoesNotExist:
#             return Response({
#                 "success": False,
#                 "message": "Product not found."
#             }, status=404)

#         except Address.DoesNotExist:
#             return Response({
#                 "success": False,
#                 "message": "Address not found."
#             }, status=404)

#         weight = float(re.findall(r"[\d.]+", product.weight)[0])

#         # Demo shipping charges
#         if weight <= 0.5:
#             base_charge = 60
#         elif weight <= 1:
#             base_charge = 80
#         elif weight <= 5:
#             base_charge = 140
#         else:
#             base_charge = 250

#         cod = payment_method.upper() == "COD"

#         couriers = [
#             {
#                 "courier_company_id": 31,
#                 "courier_name": "Delhivery Surface",
#                 "shipping_charge": base_charge,
#                 "cod_charge": 40 if cod else 0,
#                 "total_charge": base_charge + (40 if cod else 0),
#                 "delivery_days": 3,
#                 "rating": 4.8,
#                 "cod_available": True
#             },
#             {
#                 "courier_company_id": 45,
#                 "courier_name": "Xpressbees",
#                 "shipping_charge": base_charge + 15,
#                 "cod_charge": 40 if cod else 0,
#                 "total_charge": base_charge + 15 + (40 if cod else 0),
#                 "delivery_days": 2,
#                 "rating": 4.9,
#                 "cod_available": True
#             },
#             {
#                 "courier_company_id": 13,
#                 "courier_name": "DTDC",
#                 "shipping_charge": base_charge + 25,
#                 "cod_charge": 40 if cod else 0,
#                 "total_charge": base_charge + 25 + (40 if cod else 0),
#                 "delivery_days": 4,
#                 "rating": 4.6,
#                 "cod_available": True
#             }
#         ]

#         return Response({
#             "success": True,
#             "company": company.name,
#             "pickup_pincode": company.pincode,
#             "delivery_pincode": address.pincode,
#             "product": product.name,
#             "weight": product.weight,
#             "payment_method": payment_method,
#             "available_couriers": couriers
#         })
        
class MyOrdersAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user

        try:

            orders = (
                ShipOrder.objects
                .filter(user=user)
                .filter(
                    Q(payment_method="COD") |
                    Q(payment_method="PREPAID", payment_status=True)
                )
                .select_related(
                    "company",
                    "product",
                    "address"
                )
                .prefetch_related(
                    "shipment"
                )
                .order_by("-created_at")
            )

            data = []

            for order in orders:

                shipment = getattr(
                    order,
                    "shipment",
                    None
                )

                # --------------------------------
                # Cancellation
                # --------------------------------

                can_cancel = False

                if order.status not in [
                    "CANCELLED",
                    "DELIVERED",
                    "COMPLETED"
                ]:

                    if shipment:

                        if shipment.status not in [
                            "ORDER_CANCELLED",
                            "CANCELLED",
                            "DELIVERED"
                        ]:
                            can_cancel = True

                    else:
                        can_cancel = True

                # --------------------------------
                # Shipment Data
                # --------------------------------

                shipment_data = None

                if shipment:

                    shipment_data = {
                        "shipment_id": shipment.shipment_id,
                        "shiprocket_order_id": shipment.shiprocket_order_id,
                        "awb_code": shipment.awb_code,
                        "courier_company": shipment.courier_company,
                        "tracking_url": shipment.tracking_url,
                        "shipping_charge": shipment.shipping_charge,
                        "pickup_status": shipment.pickup_status,
                        "status": shipment.status,
                        "label_url": shipment.label_url,
                        "manifest_url": shipment.manifest_url,
                    }

                # --------------------------------
                # Order Data
                # --------------------------------

                data.append({

                    "order_id": order.id,

                    "order_number": order.order_number,

                    "company": {
                        "id": order.company.id
                        if order.company else None,

                        "name": order.company.name
                        if order.company else None
                    },

                    "product": {
                        "id": order.product.id
                        if order.product else None,

                        "name": order.product.name
                        if order.product else None,
                        
                        "thumbnail_s3_key": (
                        order.product.thumbnail_s3_key
                        if order.product
                        and order.product.thumbnail_s3_key
                        else None
                    ),

                        "quantity": order.quantity
                    },

                    "address": {
                        "id": order.address.id
                        if order.address else None,

                        "name": (
                            order.address.full_name
                            if order.address
                            else None
                        ),

                        "address": (
                            order.address.address_line1
                            if order.address
                            else None
                        ),

                        "address_line2": (
                            order.address.address_line2
                            if order.address
                            else None
                        ),

                        "city": (
                            order.address.city
                            if order.address
                            else None
                        ),

                        "state": (
                            order.address.state
                            if order.address
                            else None
                        ),

                        "pincode": (
                            order.address.pincode
                            if order.address
                            else None
                        ),

                        "mobile": (
                            order.address.mobile_no
                            if order.address
                            else None
                        )
                        
                    },

                    "price": order.subtotal,

                    "subtotal": order.subtotal,

                    "shipping_charge": order.shipping_charge,

                    "tax_amount": order.tax_amount,

                    "discount_amount": order.discount_amount,

                    "total_amount": order.total_amount,

                    "payment_method": order.payment_method,

                    "payment_status": order.payment_status,

                    "status": order.status,

                    "can_cancel": can_cancel,

                    "shipment": shipment_data,

                    "notes": order.notes,

                    "created_at": order.created_at,

                    "updated_at": order.updated_at
                })

            return Response(
                {
                    "success": True,

                    "message": "My orders fetched successfully.",

                    "count": len(data),

                    "data": data
                },

                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,

                    "message": "Failed to fetch orders.",

                    "error": str(e)
                },

                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            ) 
            
class MyOrderDetailAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user
        order_id = request.data.get("order_id")

        if not order_id:
            return Response(
                {
                    "success": False,
                    "message": "order_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            order = (
                ShipOrder.objects
                .filter(
                    id=order_id,
                    user=user
                )
                .select_related(
                    "company",
                    "product",
                    "address"
                )
                .prefetch_related(
                    "shipment"
                )
                .first()
            )

            if not order:
                return Response(
                    {
                        "success": False,
                        "message": "Order not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # --------------------------------
            # Shipment
            # --------------------------------

            shipment = getattr(
                order,
                "shipment",
                None
            )

            # --------------------------------
            # Cancellation
            # --------------------------------

            can_cancel = False

            if order.status not in [
                "CANCELLED",
                "DELIVERED",
                "COMPLETED"
            ]:

                if shipment:

                    if shipment.status not in [
                        "ORDER_CANCELLED",
                        "CANCELLED",
                        "DELIVERED"
                    ]:
                        can_cancel = True

                else:
                    can_cancel = True

            # --------------------------------
            # Shipment Data
            # --------------------------------

            shipment_data = None

            if shipment:

                shipment_data = {
                    "shipment_id": shipment.shipment_id,

                    "shiprocket_order_id":
                        shipment.shiprocket_order_id,

                    "awb_code":
                        shipment.awb_code,

                    "courier_company":
                        shipment.courier_company,

                    "tracking_url":
                        shipment.tracking_url,

                    "shipping_charge":
                        shipment.shipping_charge,

                    "pickup_status":
                        shipment.pickup_status,

                    "status":
                        shipment.status,

                    "label_url":
                        shipment.label_url,

                    "manifest_url":
                        shipment.manifest_url,

                    "tracking_data":
                        shipment.tracking_data
                }

            # --------------------------------
            # Order Detail
            # --------------------------------

            data = {

                "order_id": order.id,

                "order_number":
                    order.order_number,

                # Company
                "company": {

                    "id":
                        order.company.id
                        if order.company else None,

                    "name":
                        order.company.name
                        if order.company else None
                },

                # Product
                "product": {

                    "id":
                        order.product.id
                        if order.product else None,

                    "name":
                        order.product.name
                        if order.product else None,
                        
                    "thumbnail_s3_key": 
                        (
                         order.product.thumbnail_s3_key
                         if order.product
                         and order.product.thumbnail_s3_key
                         else None
                        ),    

                    "quantity":
                        order.quantity
                },

                # Address
                "address": {
                    "id": order.address.id
                    if order.address else None,

                    "name": (
                        order.address.full_name
                        if order.address
                        else None
                    ),

                    "address": (
                        order.address.address_line1
                        if order.address
                        else None
                    ),

                    "address_line2": (
                        order.address.address_line2
                        if order.address
                        else None
                    ),

                    "city": (
                        order.address.city
                        if order.address
                        else None
                    ),

                    "state": (
                        order.address.state
                        if order.address
                        else None
                    ),

                    "pincode": (
                        order.address.pincode
                        if order.address
                        else None
                    ),

                    "mobile": (
                        order.address.mobile_no
                        if order.address
                        else None
                    )
                },
                # Amount
                "price":
                    order.subtotal,

                "subtotal":
                    order.subtotal,

                "shipping_charge":
                    order.shipping_charge,

                "tax_amount":
                    order.tax_amount,

                "discount_amount":
                    order.discount_amount,

                "total_amount":
                    order.total_amount,

                # Payment
                "payment_method":
                    order.payment_method,

                "payment_status":
                    order.payment_status,

                # Status
                "status":
                    order.status,

                "can_cancel":
                    can_cancel,

                # Shipment
                "shipment":
                    shipment_data,

                # Other
                "notes":
                    order.notes,

                "created_at":
                    order.created_at,

                "updated_at":
                    order.updated_at
            }

            return Response(
                {
                    "success": True,

                    "message":
                        "Order details fetched successfully.",

                    "data": data
                },

                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,

                    "message":
                        "Failed to fetch order details.",

                    "error":
                        str(e)
                },

                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
                               


class CreateShipOrderAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        print("========================================")
        print("CREATE SHIP ORDER API")
        print("========================================")

        user = request.user

        print("User:", user)

        # =====================================================
        # GET REQUEST DATA
        # =====================================================

        product_id = request.data.get("product_id")

        address_id = request.data.get("address_id")

        quantity = int(
            request.data.get(
                "quantity",
                1
            )
        )

        payment_method = request.data.get(
            "payment_method",
            "COD"
        )

        notes = request.data.get(
            "notes",
            ""
        )

        print("Product ID:", product_id)
        print("Address ID:", address_id)
        print("Quantity:", quantity)
        print("Payment Method:", payment_method)

        # =====================================================
        # VALIDATION
        # =====================================================

        if not product_id or not address_id:

            return Response(
                {
                    "success": False,
                    "message": "product_id and address_id are required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if quantity <= 0:

            return Response(
                {
                    "success": False,
                    "message": "Quantity must be greater than 0."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET PRODUCT
        # =====================================================

        try:

            product = Product.objects.select_related(
                "company"
            ).get(
                id=product_id,
                is_active=True
            )

        except Product.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Product not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # GET ADDRESS
        # =====================================================

        try:

            address = Address.objects.get(
                id=address_id,
                user=user
            )

        except Address.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Address not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # GET COMPANY
        # =====================================================

        company = product.company

        if not company:

            return Response(
                {
                    "success": False,
                    "message": "Company not found."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # COMPANY PICKUP PINCODE
        # =====================================================

        if not company.pincode:

            return Response(
                {
                    "success": False,
                    "message": "Company pickup pincode missing."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # ADDRESS DELIVERY PINCODE
        # =====================================================

        if not address.pincode:

            return Response(
                {
                    "success": False,
                    "message": "Delivery address pincode missing."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            # =================================================
            # PRODUCT PRICE
            # =================================================

            price = (
                product.final_price
                if product.final_price
                else product.price
            )

            price = Decimal(
                str(price)
            )

            subtotal = (
                price * quantity
            )

            print("----------------------------------------")
            print("PRODUCT PRICE:", price)
            print("QUANTITY:", quantity)
            print("SUBTOTAL:", subtotal)
            print("----------------------------------------")

            # =================================================
            # PAYMENT METHOD
            # =================================================

            payment_method = payment_method.upper()

            if payment_method not in [
                "COD",
                "PREPAID"
            ]:

                return Response(
                    {
                        "success": False,
                        "message": "Invalid payment method. Use COD or PREPAID."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            cod = (
                payment_method == "COD"
            )

            # =================================================
            # PRODUCT WEIGHT
            # =================================================

            weight = float(
                product.weight or 0
            )

            length = float(
                product.length or 0
            )

            breadth = float(
                product.width or 0
            )

            height = float(
                product.height or 0
            )

            print("----------------------------------------")
            print("PRODUCT WEIGHT:", weight)
            print("LENGTH:", length)
            print("BREADTH:", breadth)
            print("HEIGHT:", height)
            print("----------------------------------------")

            # =================================================
            # SHIPROCKET SERVICEABILITY
            # =================================================

            print("Checking Shiprocket serviceability...")

            shipping_response = (
                ShiprocketService.check_serviceability(

                    pickup_pincode=company.pincode,

                    delivery_pincode=address.pincode,

                    weight=weight,

                    length=length,

                    breadth=breadth,

                    height=height,

                    cod=cod
                )
            )

            print("----------------------------------------")
            print("SHIPROCKET RESPONSE:")
            print(shipping_response)
            print("----------------------------------------")

            # =================================================
            # GET AVAILABLE COURIERS
            # =================================================

            available_couriers = (
                shipping_response
                .get(
                    "data",
                    {}
                )
                .get(
                    "available_courier_companies",
                    []
                )
            )

            print("----------------------------------------")
            print(
                "AVAILABLE COURIERS:",
                len(available_couriers)
            )
            print("----------------------------------------")

            # =================================================
            # DEFAULT COURIER VALUES
            # =================================================

            shipping_charge = Decimal(
                "0.00"
            )

            courier_id = None

            courier_name = None

            # =================================================
            # SELECT COURIER
            # =================================================

            if available_couriers:

                # ---------------------------------------------
                # Currently selecting first available courier
                # ---------------------------------------------

                courier = available_couriers[0]

                print("----------------------------------------")
                print("SELECTED COURIER:")
                print(courier)
                print("----------------------------------------")

                # =================================================
                # COURIER ID
                # =================================================

                courier_id = courier.get(
                    "courier_company_id"
                )

                # =================================================
                # COURIER NAME
                # =================================================

                courier_name = courier.get(
                    "courier_name"
                )

                # =================================================
                # FREIGHT CHARGE
                # =================================================

                freight_charge = Decimal(
                    str(
                        courier.get(
                            "freight_charge",
                            0
                        )
                    )
                )

                # =================================================
                # COD CHARGE
                # =================================================

                cod_charge = Decimal(
                    str(
                        courier.get(
                            "cod_charges",
                            0
                        )
                    )
                )

                # =================================================
                # FINAL SHIPPING CHARGE
                # =================================================

                shipping_charge = (
                    freight_charge
                )

                if cod:

                    shipping_charge += (
                        cod_charge
                    )

                print("----------------------------------------")
                print("COURIER ID:", courier_id)
                print("COURIER NAME:", courier_name)
                print("FREIGHT CHARGE:", freight_charge)
                print("COD CHARGE:", cod_charge)
                print(
                    "FINAL SHIPPING CHARGE:",
                    shipping_charge
                )
                print("----------------------------------------")

            else:

                print(
                    "No courier available."
                )

                return Response(
                    {
                        "success": False,
                        "message": "No courier available for the selected pickup and delivery pincodes."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # =================================================
            # TAX
            # =================================================

            tax_amount = Decimal(
                "0.00"
            )

            # =================================================
            # DISCOUNT
            # =================================================

            discount_amount = Decimal(
                "0.00"
            )

            # =================================================
            # TOTAL AMOUNT
            # =================================================

            total_amount = (

                subtotal

                +

                shipping_charge

                +

                tax_amount

                -

                discount_amount
            )

            print("----------------------------------------")
            print("SUBTOTAL:", subtotal)
            print("SHIPPING:", shipping_charge)
            print("TAX:", tax_amount)
            print("DISCOUNT:", discount_amount)
            print("TOTAL:", total_amount)
            print("----------------------------------------")

            # =================================================
            # GENERATE UNIQUE ORDER NUMBER
            # =================================================

            order_number = (
                "QNX"
                +
                str(
                    random.randint(
                        100000,
                        999999
                    )
                )
            )

            while ShipOrder.objects.filter(
                order_number=order_number
            ).exists():

                order_number = (
                    "QNX"
                    +
                    str(
                        random.randint(
                            100000,
                            999999
                        )
                    )
                )

            print(
                "ORDER NUMBER:",
                order_number
            )

            # =================================================
            # PAYMENT STATUS
            # =================================================

            payment_status = False

            # =================================================
            # CREATE SHIP ORDER
            # =================================================

            order = ShipOrder.objects.create(

                order_number=order_number,

                user=user,

                company=company,

                product=product,

                address=address,

                quantity=quantity,

                payment_method=payment_method,

                payment_status=payment_status,

                subtotal=subtotal,

                shipping_charge=shipping_charge,

                # =============================================
                # SHIPROCKET COURIER DETAILS
                # =============================================

                courier_id=courier_id,

                courier_name=courier_name,

                tax_amount=tax_amount,

                discount_amount=discount_amount,

                total_amount=total_amount,

                status="PENDING",

                notes=notes
            )

            print("----------------------------------------")
            print("ORDER CREATED")
            print("ORDER ID:", order.id)
            print("ORDER NUMBER:", order.order_number)
            print("COURIER ID:", order.courier_id)
            print("COURIER NAME:", order.courier_name)
            print("----------------------------------------")

            # =================================================
            # CREATE ORDER ITEM
            # =================================================

            ShipOrderItem.objects.create(

                order=order,

                product=product,

                quantity=quantity,

                price=price,

                total=subtotal
            )

            print(
                "ORDER ITEM CREATED"
            )

            # =================================================
            # RESPONSE
            # =================================================

            return Response(

                {

                    "success": True,

                    "message": (
                        "Order Created Successfully."
                    ),

                    "data": {

                        "order_id": order.id,

                        "order_number": (
                            order.order_number
                        ),

                        "company": (
                            company.name
                        ),

                        "product": (
                            product.name
                        ),

                        "quantity": (
                            order.quantity
                        ),

                        "price": (
                            order.product.final_price
                            if order.product.final_price
                            else order.product.price
                        ),

                        "subtotal": (
                            order.subtotal
                        ),

                        "shipping_charge": (
                            order.shipping_charge
                        ),

                        # =====================================
                        # SHIPROCKET COURIER
                        # =====================================

                        "courier_id": (
                            order.courier_id
                        ),

                        "courier_name": (
                            order.courier_name
                        ),

                        "tax": (
                            order.tax_amount
                        ),

                        "discount": (
                            order.discount_amount
                        ),

                        "total_amount": (
                            order.total_amount
                        ),

                        "payment_method": (
                            order.payment_method
                        ),

                        "payment_status": (
                            order.payment_status
                        ),

                        "status": (
                            order.status
                        ),

                        "created_at": (
                            order.created_at
                        )
                    }
                },

                status=status.HTTP_201_CREATED
            )

        except ValueError as e:

            return Response(

                {
                    "success": False,
                    "message": (
                        f"Invalid product value: {str(e)}"
                    )
                },

                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as e:

            print("----------------------------------------")
            print("CREATE ORDER ERROR")
            print(str(e))
            print("----------------------------------------")

            return Response(

                {
                    "success": False,
                    "message": str(e)
                },

                status=status.HTTP_400_BAD_REQUEST
            )
            

class ShipOrderListCompanyAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:

            # =====================================================
            # LOGGED-IN USER CHYA COMPANY CHE ORDERS
            # =====================================================

            orders = ShipOrder.objects.select_related(
                "user",
                "company",
                "product",
                "address",
                "shipment"
                
            ).filter(
                company__user=request.user
            ).order_by("-created_at")

            data = []

            for order in orders:

                data.append({

                    # =================================================
                    # ORDER
                    # =================================================

                    "order_id": order.id,

                    "order_number": order.order_number,
                    
                    # In your response data
                    "shipment_id": order.shipment.shipment_id if hasattr(order, 'shipment') else None,

                    # =================================================
                    # USER
                    # =================================================

                    "user": {
                        "id": order.user.id
                        if order.user else None,

                        "name": order.user.name
                        if order.user else None,

                        "phone_number": order.user.phone_number
                        if order.user else None,

                        "email": order.user.email
                        if order.user else None,
                    },

                    # =================================================
                    # COMPANY
                    # =================================================

                    "company": {
                        "id": order.company.id
                        if order.company else None,

                        "name": order.company.name
                        if order.company else None,

                        "owner_name": order.company.owner_name
                        if order.company else None,

                        "phone_number": order.company.phone_number
                        if order.company else None,

                        "email": order.company.email
                        if order.company else None,

                        "address": order.company.address
                        if order.company else None,
                    },

                    # =================================================
                    # PRODUCT
                    # =================================================

                    "product": {
                        "id": order.product.id
                        if order.product else None,

                        "name": order.product.name
                        if order.product else None,

                        "price": order.product.price
                        if order.product else 0,

                        "final_price": (
                            order.product.final_price
                            if order.product
                            and order.product.final_price is not None
                            else None
                        ),

                        "stock_quantity": (
                            order.product.stock_quantity
                            if order.product
                            else 0
                        ),

                        "thumbnail_s3_key": (
                            order.product.thumbnail_s3_key
                            if order.product
                            else None
                        ),
                    },

                    # =================================================
                    # ADDRESS
                    # =================================================

                    "address": {
                        "id": order.address.id
                        if order.address else None,

                        "full_name": order.address.full_name
                        if order.address else None,

                        "mobile_no": order.address.mobile_no
                        if order.address else None,

                        "address_line1": (
                            order.address.address_line1
                            if order.address
                            else None
                        ),

                        "city": (
                            order.address.city
                            if order.address
                            else None
                        ),

                        "state": (
                            order.address.state
                            if order.address
                            else None
                        ),

                        "pincode": (
                            order.address.pincode
                            if order.address
                            else None
                        ),
                    },

                    # =================================================
                    # ORDER AMOUNT
                    # =================================================

                    "quantity": order.quantity,

                    "price": (
                        order.product.final_price
                        if order.product
                        and order.product.final_price is not None
                        else order.product.price
                        if order.product
                        else 0
                    ),

                    "subtotal": order.subtotal,

                    "shipping_charge": order.shipping_charge,

                    "tax": order.tax_amount,

                    "discount": order.discount_amount,

                    "total_amount": order.total_amount,

                    # =================================================
                    # PAYMENT / STATUS
                    # =================================================

                    "payment_method": order.payment_method,

                    "payment_status": order.payment_status,

                    "status": order.status,

                    "notes": order.notes,

                    "created_at": order.created_at,
                })

            return Response(
                {
                    "success": True,
                    "message": "Company orders fetched successfully.",
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )
            
class ShipOrderListAPIView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        try:

            orders = ShipOrder.objects.select_related(
                "user",
                "company",
                "product",
                "address"
            ).filter(
                Q(payment_method="COD") |
                Q(payment_method="PREPAID", payment_status=True)
            ).order_by("-created_at")

            data = []

            for order in orders:

                data.append({

                    # =========================
                    # ORDER
                    # =========================

                    "order_id": order.id,

                    "order_number": order.order_number,

                    # =========================
                    # USER
                    # =========================

                    "user": {
                        "id": order.user.id
                        if order.user else None,

                        "name": order.user.name
                        if order.user else None,

                        "phone_number": order.user.phone_number
                        if order.user else None,

                        "email": order.user.email
                        if order.user else None,
                    },

                    # =========================
                    # COMPANY
                    # =========================

                    "company": {
                        "id": order.company.id
                        if order.company else None,

                        "name": order.company.name
                        if order.company else None,

                        "owner_name": order.company.owner_name
                        if order.company else None,

                        "phone_number": order.company.phone_number
                        if order.company else None,

                        "email": order.company.email
                        if order.company else None,

                        "address": order.company.address
                        if order.company else None,
                    },

                    # =========================
                    # PRODUCT
                    # =========================

                    "product": {
                        "id": order.product.id
                        if order.product else None,

                        "name": order.product.name
                        if order.product else None,

                        "price": order.product.price
                        if order.product else 0,

                        "final_price": order.product.final_price
                        if order.product
                        and order.product.final_price is not None
                        else None,

                        "stock_quantity": order.product.stock_quantity
                        if order.product else 0,

                        "thumbnail_s3_key":
                            order.product.thumbnail_s3_key
                            if order.product
                            else None,
                    },

                    # =========================
                    # ADDRESS
                    # =========================

                    "address": {
                        "id": order.address.id
                        if order.address else None,

                        "full_name": order.address.full_name
                        if order.address else None,

                        "mobile_no": order.address.mobile_no
                        if order.address else None,

                        "address_line1":
                            order.address.address_line1
                            if order.address else None,

                        "city": order.address.city
                        if order.address else None,

                        "state": order.address.state
                        if order.address else None,

                        "pincode": order.address.pincode
                        if order.address else None,
                    },

                    # =========================
                    # ORDER AMOUNT
                    # =========================

                    "quantity": order.quantity,

                    "price":
                        order.product.final_price
                        if order.product
                        and order.product.final_price is not None
                        else order.product.price
                        if order.product
                        else 0,

                    "subtotal": order.subtotal,

                    "shipping_charge": order.shipping_charge,

                    "tax": order.tax_amount,

                    "discount": order.discount_amount,

                    "total_amount": order.total_amount,

                    # =========================
                    # PAYMENT / STATUS
                    # =========================

                    "payment_method":
                        order.payment_method,

                    "payment_status":
                        order.payment_status,

                    "status":
                        order.status,

                    "notes":
                        order.notes,

                    "created_at":
                        order.created_at,
                })

            return Response(
                {
                    "success": True,
                    "message": "Orders fetched successfully.",
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_400_BAD_REQUEST
            )
            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from shiprocket.models import ShipOrder, Shipment
from state.services.shiprocket import ShiprocketService


class ShiprocketCreateOrderAPIView(APIView):

    def post(self, request):

        order_id = request.data.get("order_id")

        if not order_id:
            return Response(
                {
                    "success": False,
                    "message": "order_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            order = ShipOrder.objects.select_related(
                "product",
                "company",
                "address",
                "user"
            ).get(id=order_id)

        except ShipOrder.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        product = order.product
        company = order.company
        address = order.address

        payload = {

            "order_id": order.order_number,

            "order_date": order.created_at.strftime("%Y-%m-%d %H:%M"),

            "pickup_location": company.pickup_location,

            "billing_customer_name": address.full_name,

            "billing_last_name": "",

            "billing_address": address.address_line1,

            "billing_address_2": address.address_line2 or "",

            "billing_city": address.city,

            "billing_pincode": address.pincode,

            "billing_state": address.state,

            "billing_country": "India",

            "billing_email": order.user.email if order.user else "",

            "billing_phone": address.mobile_no,

            "shipping_is_billing": True,

            "order_items": [
                {
                    "name": product.name,
                    "sku": product.product_code or str(product.id),
                    "units": order.quantity,
                    "selling_price": str(
                        product.final_price if product.final_price else product.price
                    )
                }
            ],

            "payment_method": order.payment_method,

            "sub_total": str(order.total_amount),

            "length": float(product.length.split()[0]),

            "breadth": float(product.width.split()[0]),

            "height": float(product.height.split()[0]),

            "weight": float(product.weight.split()[0])
        }

        print("========== Shiprocket Payload ==========")
        print(payload)

        try:

            response = ShiprocketService.create_order(payload)

            print("========== Shiprocket Response ==========")
            print(response)

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # -------------------------------
        # Save data if order created
        # -------------------------------

        if response.get("status_code") == 1:

            # Update Local Order
            order.status = "CONFIRMED"
            order.save()

            # Create or Update Shipment
            shipment, created = Shipment.objects.get_or_create(
                order=order
            )

            shipment.shiprocket_order_id = str(
                response.get("order_id", "")
            )

            shipment.shipment_id = str(
                response.get("shipment_id", "")
            )

            shipment.awb_code = response.get("awb_code") or ""

            shipment.courier_company = response.get("courier_name") or ""

            shipment.status = response.get("status") or "NEW"

            if response.get("shipping_charges"):
                shipment.shipping_charge = response.get("shipping_charges")

            shipment.save()

            print("Shipment Saved Successfully")
            print("Shipment ID :", shipment.id)

        return Response(
            {
                "success": True,
                "shiprocket_response": response
            }
        )
        
class ShipmentListAPIView(APIView):

    def post(self, request):
        try:
            shipments = Shipment.objects.select_related(
                "order"
            ).order_by("-created_at")

            serializer = ShipmentListSerializer(
                shipments,
                many=True
            )

            return Response({
                "success": True,
                "message": "Shipment list fetched successfully.",
                "count": shipments.count(),
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({
                "success": False,
                "message": "Failed to fetch shipment list.",
                "error": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                    
# class AssignAWBAPIView(APIView):

#     authentication_classes = [JWTAuthentication]
#     permission_classes = [IsAuthenticated]

#     def post(self, request):

#         shipment_id = request.data.get("shipment_id")
#         courier_id = request.data.get("courier_id")

#         # --------------------------------
#         # Validate Shipment ID
#         # --------------------------------
#         if not shipment_id:
#             return Response(
#                 {
#                     "success": False,
#                     "message": "shipment_id is required."
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         # --------------------------------
#         # Validate Courier ID
#         # --------------------------------
#         if not courier_id:
#             return Response(
#                 {
#                     "success": False,
#                     "message": "courier_id is required."
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         # --------------------------------
#         # Find Shipment
#         # --------------------------------
#         try:

#             shipment = Shipment.objects.get(
#                 shipment_id=str(shipment_id)
#             )

#         except Shipment.DoesNotExist:

#             return Response(
#                 {
#                     "success": False,
#                     "message": "Shipment not found."
#                 },
#                 status=status.HTTP_404_NOT_FOUND
#             )

#         # --------------------------------
#         # Assign AWB
#         # --------------------------------
#         try:

#             response = ShiprocketService.assign_awb(
#                 shipment_id=shipment_id,
#                 courier_company_id=courier_id
#             )

#             print("========================================")
#             print("        SHIPROCKET ASSIGN AWB")
#             print("========================================")
#             print("Shipment ID :", shipment_id)
#             print("Courier ID  :", courier_id)
#             print("Response    :", response)
#             print("========================================")

#             # --------------------------------
#             # Check AWB Assignment Status
#             # --------------------------------
#             if response.get("awb_assign_status") == 1:

#                 data = response.get(
#                     "response",
#                     {}
#                 )

#                 # Shiprocket response:
#                 #
#                 # response:
#                 # {
#                 #     "data": {
#                 #         ...
#                 #     }
#                 # }
#                 #
#                 if isinstance(data, dict) and "data" in data:
#                     data = data["data"]

#                 # --------------------------------
#                 # Extract AWB Data
#                 # --------------------------------

#                 awb_code = data.get(
#                     "awb_code"
#                 )

#                 assigned_courier_id = data.get(
#                     "courier_company_id"
#                 )

#                 courier_name = data.get(
#                     "courier_name"
#                 )

#                 freight_charges = data.get(
#                     "freight_charges"
#                 )

#                 # --------------------------------
#                 # Update Shipment
#                 # --------------------------------

#                 shipment.awb_code = awb_code

#                 shipment.courier_company = courier_name

#                 shipment.status = "AWB_ASSIGNED"

#                 if freight_charges is not None:
#                     shipment.shipping_charge = freight_charges

#                 shipment.save(
#                     update_fields=[
#                         "awb_code",
#                         "courier_company",
#                         "shipping_charge",
#                         "status",
#                         "updated_at"
#                     ]
#                 )

#                 # --------------------------------
#                 # Success Response
#                 # --------------------------------

#                 return Response(
#                     {
#                         "success": True,
#                         "message": "AWB assigned successfully.",

#                         "requested": {
#                             "shipment_id": shipment_id,
#                             "courier_id": courier_id
#                         },

#                         "assigned": {
#                             "courier_company_id": assigned_courier_id,
#                             "courier_name": courier_name,
#                             "awb_code": awb_code,
#                             "freight_charges": freight_charges
#                         },

#                         "data": response
#                     },
#                     status=status.HTTP_200_OK
#                 )

#             # --------------------------------
#             # AWB Assignment Failed
#             # --------------------------------

#             return Response(
#                 {
#                     "success": False,
#                     "message": "AWB assignment failed.",

#                     "requested": {
#                         "shipment_id": shipment_id,
#                         "courier_id": courier_id
#                     },

#                     "data": response
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         except Exception as e:

#             print("========== Assign AWB Exception ==========")
#             print(str(e))

#             return Response(
#                 {
#                     "success": False,
#                     "message": "Something went wrong while assigning AWB.",
#                     "error": str(e)
#                 },
#                 status=status.HTTP_500_INTERNAL_SERVER_ERROR
#             )
class AssignAWBAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        # --------------------------------
        # Validate Shipment ID
        # --------------------------------
        if not shipment_id:

            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # --------------------------------
        # Find Shipment
        # --------------------------------
        try:

            shipment = Shipment.objects.select_related(
                "order"
            ).get(
                shipment_id=str(shipment_id)
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # --------------------------------
        # Get Order
        # --------------------------------
        order = shipment.order

        if not order:

            return Response(
                {
                    "success": False,
                    "message": "Order not found for this shipment."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # --------------------------------
        # Get Courier ID From Order
        # --------------------------------

        courier_id = order.courier_id

        if not courier_id:

            return Response(
                {
                    "success": False,
                    "message": "Courier ID not found in order."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        print("========================================")
        print("        ASSIGN AWB")
        print("========================================")
        print("Shipment ID :", shipment_id)
        print("Order ID    :", order.id)
        print("Order No    :", order.order_number)
        print("Courier ID  :", courier_id)
        print("Courier     :", order.courier_name)
        print("========================================")

        # --------------------------------
        # Assign AWB
        # --------------------------------
        try:

            response = ShiprocketService.assign_awb(

                shipment_id=shipment_id,

                courier_company_id=courier_id
            )

            print("========================================")
            print("        SHIPROCKET ASSIGN AWB")
            print("========================================")
            print("Shipment ID :", shipment_id)
            print("Courier ID  :", courier_id)
            print("Response    :", response)
            print("========================================")

            # --------------------------------
            # Check AWB Assignment Status
            # --------------------------------

            if response.get("awb_assign_status") == 1:

                data = response.get(
                    "response",
                    {}
                )

                # --------------------------------
                # Handle Nested Data
                # --------------------------------

                if (
                    isinstance(data, dict)
                    and
                    "data" in data
                ):

                    data = data["data"]

                # --------------------------------
                # Extract AWB Data
                # --------------------------------

                awb_code = data.get(
                    "awb_code"
                )

                assigned_courier_id = data.get(
                    "courier_company_id"
                )

                courier_name = data.get(
                    "courier_name"
                )

                freight_charges = data.get(
                    "freight_charges"
                )

                # --------------------------------
                # Update Shipment
                # --------------------------------

                shipment.awb_code = awb_code

                shipment.courier_company = (
                    courier_name
                )

                shipment.status = (
                    "AWB_ASSIGNED"
                )

                if freight_charges is not None:

                    shipment.shipping_charge = (
                        freight_charges
                    )

                shipment.save(
                    update_fields=[
                        "awb_code",
                        "courier_company",
                        "shipping_charge",
                        "status",
                        "updated_at"
                    ]
                )

                # --------------------------------
                # Also Update Order Courier
                # --------------------------------

                if assigned_courier_id:

                    order.courier_id = (
                        assigned_courier_id
                    )

                if courier_name:

                    order.courier_name = (
                        courier_name
                    )

                if freight_charges is not None:

                    order.shipping_charge = (
                        freight_charges
                    )

                order.save(
                    update_fields=[
                        "courier_id",
                        "courier_name",
                        "shipping_charge",
                        "updated_at"
                    ]
                )

                # --------------------------------
                # Success Response
                # --------------------------------

                return Response(
                    {
                        "success": True,

                        "message": (
                            "AWB assigned successfully."
                        ),

                        "requested": {
                            "shipment_id": shipment_id
                        },

                        "order": {

                            "order_id": order.id,

                            "order_number": (
                                order.order_number
                            ),

                            "courier_id": (
                                order.courier_id
                            ),

                            "courier_name": (
                                order.courier_name
                            )
                        },

                        "assigned": {

                            "courier_company_id": (
                                assigned_courier_id
                            ),

                            "courier_name": (
                                courier_name
                            ),

                            "awb_code": (
                                awb_code
                            ),

                            "freight_charges": (
                                freight_charges
                            )
                        },

                        "data": response
                    },

                    status=status.HTTP_200_OK
                )

            # --------------------------------
            # AWB Assignment Failed
            # --------------------------------

            return Response(
                {
                    "success": False,

                    "message": (
                        "AWB assignment failed."
                    ),

                    "shipment_id": shipment_id,

                    "order_id": order.id,

                    "order_number": (
                        order.order_number
                    ),

                    "courier_id": courier_id,

                    "courier_name": (
                        order.courier_name
                    ),

                    "data": response
                },

                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as e:

            print(
                "========== Assign AWB Exception =========="
            )

            print(
                str(e)
            )

            return Response(
                {
                    "success": False,

                    "message": (
                        "Something went wrong while assigning AWB."
                    ),

                    "error": str(e)
                },

                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
class GenerateLabelAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            shipment = Shipment.objects.get(
                shipment_id=str(shipment_id)
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        try:

            response = ShiprocketService.generate_label(shipment_id)

            print(response)

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Save label URL if available
        if response.get("label_created") == 1:

            shipment.label_url = (
                response.get("label_url")
                or response.get("label_download")
                or ""
            )

            shipment.save()

        return Response(
            {
                "success": True,
                "shiprocket_response": response
            }
        )    
        
        
class PickupRequestAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            shipment = Shipment.objects.get(
                shipment_id=str(shipment_id)
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        try:

            response = ShiprocketService.request_pickup(shipment_id)

            print(response)

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        if response.get("pickup_status") == 1:

            shipment.pickup_request_id = str(
                response.get("request_id", "")
            )

            shipment.pickup_status = "REQUESTED"

            shipment.save()

        return Response(
            {
                "success": True,
                "shiprocket_response": response
            }
        )        
        
        
class TrackShipmentAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            shipment = Shipment.objects.get(
                shipment_id=str(shipment_id)
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        try:

            response = ShiprocketService.track_shipment(
                shipment.shipment_id
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Save tracking response
        shipment.tracking_data = response

        tracking_data = response.get("tracking_data", {})
        shipment_track = tracking_data.get("shipment_track", [])

        if shipment_track:

            latest = shipment_track[0]

            shipment.status = latest.get(
                "current_status",
                shipment.status
            )

            if latest.get("awb_code"):
                shipment.awb_code = latest.get("awb_code")

            if latest.get("courier_name"):
                shipment.courier_company = latest.get("courier_name")

        shipment.save()

        return Response(
            {
                "success": True,
                "message": "Shipment tracked successfully.",
                "data": response
            }
        )  
        
class GenerateManifestAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            shipment = Shipment.objects.get(
                shipment_id=str(shipment_id)
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        try:

            response = ShiprocketService.generate_manifest(
                shipment.shipment_id
            )

            print(response)

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        if response.get("manifest_url"):

            shipment.manifest_url = response.get("manifest_url")
            shipment.save()

        return Response(
            {
                "success": True,
                "message": "Manifest generated successfully.",
                "data": response
            }
        ) 
        
        
class CancelOrderAPIView(APIView):

    def post(self, request):

        order_id = request.data.get("order_id")

        if not order_id:
            return Response(
                {
                    "success": False,
                    "message": "order_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            shipment = Shipment.objects.select_related("order").get(
                order__id=order_id
            )

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # Shiprocket order id check
        if not shipment.shiprocket_order_id:
            return Response(
                {
                    "success": False,
                    "message": "Shiprocket order ID not found."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            response = ShiprocketService.cancel_order(
                shipment.shiprocket_order_id
            )

        except requests.exceptions.HTTPError as e:

            return Response(
                {
                    "success": False,
                    "message": "Shiprocket order cancellation failed.",
                    "error": str(e),
                    "shiprocket_response": (
                        e.response.json()
                        if e.response is not None
                        else None
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except requests.exceptions.RequestException as e:

            return Response(
                {
                    "success": False,
                    "message": "Unable to connect with Shiprocket.",
                    "error": str(e)
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        # Print response for debugging
        print("===================================")
        print("SHIPROCKET CANCEL ORDER RESPONSE")
        print(response)
        print("===================================")

        # Check Shiprocket response
        message = str(
            response.get("message", "")
        ).lower()

        # Failure response
        if "cannot" in message or "failed" in message or "error" in message:

            return Response(
                {
                    "success": False,
                    "message": response.get(
                        "message",
                        "Order cancellation failed."
                    ),
                    "data": response
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # SUCCESS
        shipment.status = "ORDER_CANCELLED"
        shipment.pickup_status = "CANCELLED"

        shipment.save(
            update_fields=[
                "status",
                "pickup_status"
            ]
        )

        # Update Order
        shipment.order.status = "CANCELLED"
        shipment.order.save(
            update_fields=["status"]
        )

        return Response(
            {
                "success": True,
                "message": "Order cancelled successfully.",
                "data": response
            },
            status=status.HTTP_200_OK
        )          
        
     
        
class CancelPickupAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            shipment = Shipment.objects.get(
                shipment_id=shipment_id
            )

        except Shipment.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Shipment not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # AWB validation
        if not shipment.awb_code:
            return Response(
                {
                    "success": False,
                    "message": "AWB not found for this shipment."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Already cancelled locally
        if shipment.status == "ORDER_CANCELLED":
            return Response(
                {
                    "success": False,
                    "message": "Order is already cancelled.",
                    "shipment_id": shipment.shipment_id,
                    "awb_code": shipment.awb_code
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            response = ShiprocketService.cancel_shipment_by_awb(
                shipment.awb_code
            )

        except requests.exceptions.HTTPError as e:

            return Response(
                {
                    "success": False,
                    "message": "Shiprocket cancellation failed.",
                    "error": str(e),
                    "shiprocket_response": (
                        e.response.json()
                        if e.response is not None
                        else None
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except requests.exceptions.RequestException as e:

            return Response(
                {
                    "success": False,
                    "message": "Unable to connect with Shiprocket.",
                    "error": str(e)
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        # Shiprocket business-level failure
        message = str(
            response.get("message", "")
        ).lower()

        if "cannot be cancelled" in message:

            return Response(
                {
                    "success": False,
                    "message": response.get(
                        "message",
                        "AWB cannot be cancelled."
                    ),
                    "shipment_id": shipment.shipment_id,
                    "awb_code": shipment.awb_code,
                    "data": response
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Only after successful Shiprocket cancellation
        shipment.pickup_status = "CANCELLED"
        shipment.status = "ORDER_CANCELLED"

        shipment.save(
            update_fields=[
                "pickup_status",
                "status"
            ]
        )

        return Response(
            {
                "success": True,
                "message": "Shipment cancelled successfully.",
                "shipment_id": shipment.shipment_id,
                "awb_code": shipment.awb_code,
                "data": response
            },
            status=status.HTTP_200_OK
        )    
                 
                 
                 
class DownloadLabelAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": "shipment_id is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:

            response = ShiprocketService.download_label(
                shipment_id
            )

            return Response(
                {
                    "success": True,
                    "message": "Label generated successfully.",
                    "data": response
                },
                status=status.HTTP_200_OK
            )

        except requests.exceptions.HTTPError as e:

            return Response(
                {
                    "success": False,
                    "message": "Shiprocket label API failed.",
                    "error": str(e),

                    "shipment_id": shipment_id
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Something went wrong while downloading label.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated
import requests


class DownloadMultipleLabelsMultipleAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        shipment_ids = request.data.get("shipment_ids")

        # --------------------------------------------------
        # VALIDATION
        # --------------------------------------------------
        if not shipment_ids:
            return Response(
                {
                    "success": False,
                    "message": "shipment_ids is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not isinstance(shipment_ids, list):
            return Response(
                {
                    "success": False,
                    "message": "shipment_ids must be a list."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(shipment_ids) == 0:
            return Response(
                {
                    "success": False,
                    "message": "At least one shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # --------------------------------------------------
        # REMOVE DUPLICATE IDS
        # --------------------------------------------------
        shipment_ids = list(dict.fromkeys(shipment_ids))

        results = []

        success_count = 0
        failed_count = 0

        # --------------------------------------------------
        # DOWNLOAD / GENERATE LABEL FOR EACH SHIPMENT
        # --------------------------------------------------
        for shipment_id in shipment_ids:

            try:

                response = ShiprocketService.download_label(
                    shipment_id
                )

                results.append(
                    {
                        "shipment_id": shipment_id,
                        "success": True,
                        "message": "Label generated successfully.",
                        "data": response
                    }
                )

                success_count += 1

            except requests.exceptions.HTTPError as e:

                failed_count += 1

                error_message = str(e)

                # Try to get Shiprocket response
                try:
                    if e.response is not None:
                        error_message = e.response.text
                except Exception:
                    pass

                results.append(
                    {
                        "shipment_id": shipment_id,
                        "success": False,
                        "message": "Shiprocket label API failed.",
                        "error": error_message
                    }
                )

            except Exception as e:

                failed_count += 1

                results.append(
                    {
                        "shipment_id": shipment_id,
                        "success": False,
                        "message": "Something went wrong while downloading label.",
                        "error": str(e)
                    }
                )

        # --------------------------------------------------
        # FINAL RESPONSE
        # --------------------------------------------------

        if success_count == len(shipment_ids):

            return Response(
                {
                    "success": True,
                    "message": "All labels generated successfully.",
                    "total_shipments": len(shipment_ids),
                    "success_count": success_count,
                    "failed_count": failed_count,
                    "data": results
                },
                status=status.HTTP_200_OK
            )

        elif success_count > 0:

            return Response(
                {
                    "success": True,
                    "message": "Some labels generated successfully and some failed.",
                    "total_shipments": len(shipment_ids),
                    "success_count": success_count,
                    "failed_count": failed_count,
                    "data": results
                },
                status=status.HTTP_207_MULTI_STATUS
            )

        else:

            return Response(
                {
                    "success": False,
                    "message": "Failed to generate all labels.",
                    "total_shipments": len(shipment_ids),
                    "success_count": success_count,
                    "failed_count": failed_count,
                    "data": results
                },
                status=status.HTTP_400_BAD_REQUEST
            )   
            
import requests
from io import BytesIO

from django.http import HttpResponse

from rest_framework.views import APIView
from rest_framework import status
from rest_framework.response import Response

from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated

from pypdf import PdfReader, PdfWriter


class DownloadMultipleLabelsPDFAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        shipment_ids = request.data.get("shipment_ids")

        # -----------------------------------------
        # VALIDATION
        # -----------------------------------------

        if not shipment_ids:

            return Response(
                {
                    "success": False,
                    "message": "shipment_ids is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not isinstance(shipment_ids, list):

            return Response(
                {
                    "success": False,
                    "message": "shipment_ids must be a list."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if len(shipment_ids) == 0:

            return Response(
                {
                    "success": False,
                    "message": "At least one shipment_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Remove duplicate shipment IDs
        shipment_ids = list(dict.fromkeys(shipment_ids))

        writer = PdfWriter()

        failed_shipments = []
        success_shipments = []

        # -----------------------------------------
        # PROCESS EACH SHIPMENT
        # -----------------------------------------

        for shipment_id in shipment_ids:

            try:

                # -----------------------------------------
                # CALL SHIPROCKET LABEL API
                # -----------------------------------------

                label_response = ShiprocketService.download_label(
                    shipment_id
                )

                print(
                    f"Label response for {shipment_id}:",
                    label_response
                )

                # -----------------------------------------
                # GET LABEL URL
                # -----------------------------------------

                label_url = None

                if isinstance(label_response, dict):

                    label_url = (
                        label_response.get("label_url")
                        or label_response.get("url")
                        or label_response.get("label")
                    )

                # Sometimes response can be nested
                if not label_url and isinstance(label_response, dict):

                    data = label_response.get("data")

                    if isinstance(data, dict):

                        label_url = (
                            data.get("label_url")
                            or data.get("url")
                            or data.get("label")
                        )

                if not label_url:

                    failed_shipments.append(
                        {
                            "shipment_id": shipment_id,
                            "error": "Label URL not found."
                        }
                    )

                    continue

                # -----------------------------------------
                # DOWNLOAD LABEL PDF
                # -----------------------------------------

                pdf_response = requests.get(
                    label_url,
                    timeout=60
                )

                pdf_response.raise_for_status()

                # -----------------------------------------
                # READ PDF
                # -----------------------------------------

                pdf_file = BytesIO(pdf_response.content)

                reader = PdfReader(pdf_file)

                # -----------------------------------------
                # ADD ALL PAGES
                # -----------------------------------------

                for page in reader.pages:

                    writer.add_page(page)

                success_shipments.append(shipment_id)

            except requests.exceptions.RequestException as e:

                failed_shipments.append(
                    {
                        "shipment_id": shipment_id,
                        "error": f"PDF download failed: {str(e)}"
                    }
                )

            except Exception as e:

                failed_shipments.append(
                    {
                        "shipment_id": shipment_id,
                        "error": str(e)
                    }
                )

        # -----------------------------------------
        # NO PDF GENERATED
        # -----------------------------------------

        if not success_shipments:

            return Response(
                {
                    "success": False,
                    "message": "No labels could be generated.",
                    "total_shipments": len(shipment_ids),
                    "success_count": 0,
                    "failed_count": len(failed_shipments),
                    "failed_shipments": failed_shipments
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # -----------------------------------------
        # CREATE FINAL PDF
        # -----------------------------------------

        output = BytesIO()

        writer.write(output)

        output.seek(0)

        # -----------------------------------------
        # RESPONSE
        # -----------------------------------------

        response = HttpResponse(
            output.getvalue(),
            content_type="application/pdf"
        )

        response["Content-Disposition"] = (
            'attachment; filename="multiple_labels.pdf"'
        )

        # Optional custom headers
        response["X-Total-Shipments"] = str(
            len(shipment_ids)
        )

        response["X-Success-Count"] = str(
            len(success_shipments)
        )

        response["X-Failed-Count"] = str(
            len(failed_shipments)
        )

        return response                     



class DownloadInvoiceAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:

            # --------------------------------
            # Get Order ID
            # --------------------------------

            order_id = request.data.get("order_id")

            print("===================================")
            print("DOWNLOAD INVOICE API")
            print("REQUEST USER:", request.user)
            print("REQUEST USER ID:", request.user.id)
            print("ORDER ID:", order_id)
            print("===================================")

            if not order_id:

                return Response(
                    {
                        "success": False,
                        "message": "order_id is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # Get Order
            # --------------------------------

            try:

                order = (
                    ShipOrder.objects
                    .select_related(
                        "shipment",
                        "company",
                        "company__user",
                        "product",
                        "user"
                    )
                    .get(id=order_id)
                )

            except ShipOrder.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Order not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            print("-----------------------------------")
            print("ORDER ID:", order.id)
            print("ORDER NUMBER:", order.order_number)
            print("CUSTOMER USER ID:", order.user_id)
            print("COMPANY ID:", order.company_id)
            print("COMPANY USER ID:", order.company.user_id)
            print("-----------------------------------")

            # --------------------------------
            # Authorization
            # --------------------------------

            is_customer = (
                order.user_id == request.user.id
            )

            is_company_user = (
                order.company.user_id == request.user.id
            )

            print("IS CUSTOMER:", is_customer)
            print("IS COMPANY USER:", is_company_user)

            if not is_customer and not is_company_user:

                return Response(
                    {
                        "success": False,
                        "message": "You are not authorized to download this invoice."
                    },
                    status=status.HTTP_403_FORBIDDEN
                )

            # --------------------------------
            # Get Shipment
            # --------------------------------

            try:

                shipment = order.shipment

            except Shipment.DoesNotExist:

                return Response(
                    {
                        "success": False,
                        "message": "Shipment not found for this order."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            print("-----------------------------------")
            print("SHIPMENT ID:", shipment.id)
            print(
                "SHIPROCKET ORDER ID:",
                shipment.shiprocket_order_id
            )
            print("-----------------------------------")

            # --------------------------------
            # Validate Shiprocket Order ID
            # --------------------------------

            if not shipment.shiprocket_order_id:

                return Response(
                    {
                        "success": False,
                        "message": "Shiprocket order ID not found."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # --------------------------------
            # Download Invoice
            # --------------------------------

            try:

                response = ShiprocketService.download_invoice(
                    shipment.shiprocket_order_id
                )

                print("===================================")
                print("SHIPROCKET INVOICE RESPONSE")
                print(response)
                print("===================================")

            except requests.exceptions.HTTPError as e:

                print("SHIPROCKET HTTP ERROR:", str(e))

                return Response(
                    {
                        "success": False,
                        "message": "Shiprocket invoice request failed.",
                        "shiprocket_response": (
                            e.response.text
                            if e.response is not None
                            else None
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            except requests.exceptions.RequestException as e:

                print("SHIPROCKET REQUEST ERROR:", str(e))

                return Response(
                    {
                        "success": False,
                        "message": "Unable to connect to Shiprocket.",
                        "error": str(e)
                    },
                    status=status.HTTP_502_BAD_GATEWAY
                )

            # --------------------------------
            # Success
            # --------------------------------

            return Response(
                {
                    "success": True,
                    "message": "Invoice downloaded successfully.",
                    "order_id": order.id,
                    "order_number": order.order_number,
                    "shiprocket_order_id": shipment.shiprocket_order_id,
                    "user_type": (
                        "company_user"
                        if is_company_user
                        else "customer"
                    ),
                    "data": response
                },
                status=status.HTTP_200_OK
            )

        # --------------------------------
        # Catch Any Unexpected Error
        # --------------------------------

        except Exception as e:

            import traceback

            print("===================================")
            print("DOWNLOAD INVOICE ERROR")
            print("ERROR:", str(e))
            print("TRACEBACK:")
            traceback.print_exc()
            print("===================================")

            return Response(
                {
                    "success": False,
                    "message": "Internal server error.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class DownloadManifestAPIView(APIView):

    def post(self, request):

        shipment_id = request.data.get("shipment_id")

        if not shipment_id:
            return Response(
                {"success": False, "message": "shipment_id is required"},
                status=400
            )

        response = ShiprocketService.download_manifest(shipment_id)

        return Response({
            "success": True,
            "data": response
        })        
        
        
class ReturnOrderAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        print("========================================")
        print("RETURN ORDER API")
        print("========================================")

        user = request.user

        # =====================================================
        # REQUEST DATA
        # =====================================================

        order_id = request.data.get("order_id")
        reason = request.data.get("reason")
        reason_note = request.data.get("reason_note", "")

        try:
            quantity = int(
                request.data.get("quantity", 1)
            )
        except (TypeError, ValueError):

            return Response(
                {
                    "success": False,
                    "message": "Quantity must be a valid number."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        print("User:", user)
        print("Order ID:", order_id)
        print("Quantity:", quantity)
        print("Reason:", reason)

        # =====================================================
        # BASIC VALIDATION
        # =====================================================

        if not order_id:

            return Response(
                {
                    "success": False,
                    "message": "order_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not reason:

            return Response(
                {
                    "success": False,
                    "message": "Return reason is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if quantity <= 0:

            return Response(
                {
                    "success": False,
                    "message": "Quantity must be greater than 0."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET ORDER
        # =====================================================

        try:

            order = ShipOrder.objects.select_related(
                "product",
                "company",
                "address",
                "user"
            ).get(
                id=order_id,
                user=user
            )

        except ShipOrder.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # ONLY DELIVERED ORDER CAN BE RETURNED
        # =====================================================

        if order.status != "DELIVERED":

            return Response(
                {
                    "success": False,
                    "message": (
                        "Only delivered orders can be returned."
                    ),
                    "current_status": order.status
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # QUANTITY VALIDATION
        # =====================================================

        if quantity > order.quantity:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Return quantity cannot be greater "
                        "than ordered quantity."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # CHECK EXISTING RETURN
        # =====================================================

        existing_return = ReturnOrder.objects.filter(
            order=order,
            status__in=[
                "REQUESTED",
                "APPROVED",
                "SHIPMENT_CREATED",
                "AWB_ASSIGNED",
                "PICKUP_PENDING",
                "PICKED_UP",
                "IN_TRANSIT"
            ]
        ).first()

        if existing_return:

            return Response(
                {
                    "success": False,
                    "message": "Return already exists.",
                    "return_id": existing_return.id,
                    "return_number": (
                        existing_return.return_number
                    ),
                    "return_status": (
                        existing_return.status
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # ORIGINAL SHIPMENT
        # =====================================================

        try:

            shipment = order.shipment

        except Shipment.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": (
                        "Original shipment not found."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        print("----------------------------------------")
        print("ORIGINAL SHIPMENT")
        print(
            "Shiprocket Order ID:",
            shipment.shiprocket_order_id
        )
        print(
            "Shipment ID:",
            shipment.shipment_id
        )
        print(
            "AWB:",
            shipment.awb_code
        )
        print(
            "Courier:",
            shipment.courier_company
        )
        print("----------------------------------------")

        # =====================================================
        # GENERATE RETURN NUMBER
        # =====================================================

        return_number = (
            f"RET-{order.order_number}"
        )

        # =====================================================
        # CHECK RETURN NUMBER
        # =====================================================

        if ReturnOrder.objects.filter(
            return_number=return_number
        ).exists():

            return Response(
                {
                    "success": False,
                    "message": (
                        "Return request already exists "
                        "for this order."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # REFUND AMOUNT
        # =====================================================

        # Full order return
        if quantity == order.quantity:

            refund_amount = order.total_amount

        else:

            # Partial return
            unit_price = (
                order.subtotal / order.quantity
            )

            refund_amount = (
                unit_price * quantity
            )

        # =====================================================
        # CREATE RETURN
        # =====================================================

        return_order = ReturnOrder.objects.create(

            return_number=return_number,

            order=order,

            quantity=quantity,

            reason=reason,

            reason_note=reason_note,

            refund_amount=refund_amount,

            status="REQUESTED"
        )

        # =====================================================
        # IMPORTANT
        # =====================================================
        # DO NOT CHANGE:
        #
        # order.status = "RETURN_REQUESTED"
        #
        # Original order must remain DELIVERED.
        # Return status is maintained in ReturnOrder.
        # =====================================================

        print("----------------------------------------")
        print("RETURN CREATED")
        print(
            "Return ID:",
            return_order.id
        )
        print(
            "Return Number:",
            return_order.return_number
        )
        print(
            "Return Status:",
            return_order.status
        )
        print(
            "Original Order Status:",
            order.status
        )
        print("----------------------------------------")

        # =====================================================
        # RESPONSE
        # =====================================================

        return Response(
            {
                "success": True,

                "message": (
                    "Return request created successfully."
                ),

                "data": {

                    "return_id":
                        return_order.id,

                    "return_number":
                        return_order.return_number,

                    "order_id":
                        order.id,

                    "order_number":
                        order.order_number,

                    "product":
                        order.product.name,

                    "quantity":
                        return_order.quantity,

                    "reason":
                        return_order.reason,

                    "reason_note":
                        return_order.reason_note,

                    "refund_amount":
                        return_order.refund_amount,

                    "status":
                        return_order.status,

                    # Important
                    "order_status":
                        order.status,

                    "original_shipment": {

                        "shiprocket_order_id":
                            shipment.shiprocket_order_id,

                        "shipment_id":
                            shipment.shipment_id,

                        "awb_code":
                            shipment.awb_code,

                        "courier_company":
                            shipment.courier_company
                    }
                }
            },

            status=status.HTTP_201_CREATED
        )        
   
class ReturnOrderListAPIView(APIView):

    def post(self, request):

        return_orders = (
            ReturnOrder.objects
            .select_related(
                "order",
                "order__product",
                "order__company",
                "order__address"
            )
            .order_by("-id")
        )

        data = []

        for return_order in return_orders:

            order = return_order.order

            data.append({
                "return_id": return_order.id,
                "return_number": return_order.return_number,

                "order_id": order.id,
                "order_number": order.order_number,

                "product": (
                    order.product.name
                    if order.product
                    else None
                ),

                "quantity": return_order.quantity,

                "reason": return_order.reason,

                "reason_note": return_order.reason_note,

                "refund_amount": return_order.refund_amount,

                "status": return_order.status,

                "order_status": order.status,

                "created_at": return_order.created_at,

                "updated_at": return_order.updated_at,
            })

        return Response(
            {
                "success": True,
                "message": "Return orders fetched successfully.",
                "count": len(data),
                "data": data
            },
            status=status.HTTP_200_OK
        )       
        
        


class ReturnShiprocketOrderAPIView(APIView):

    # सध्या तुमच्या जुन्या code प्रमाणे authentication commented आहे.
    # Production मध्ये authentication enable करणे सुरक्षित आहे.
    # authentication_classes = [JWTAuthentication]
    # permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user
        return_id = request.data.get("return_id")

        if not return_id:
            return Response(
                {
                    "success": False,
                    "message": "return_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET RETURN ORDER
        # =====================================================

        try:
            return_order = ReturnOrder.objects.select_related(
                "order",
                "order__product",
                "order__company",
                "order__address",
                "order__user"
            ).get(
                id=return_id,
                order__user=user
            )

        except (ReturnOrder.DoesNotExist, ValueError, TypeError):
            return Response(
                {
                    "success": False,
                    "message": "Return order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # PREVENT DUPLICATE SHIPMENT CREATION
        # =====================================================

        if (
            return_order.shipment_id
            and str(return_order.shipment_id).strip()
        ):
            return Response(
                {
                    "success": True,
                    "message": "Return shipment already exists.",
                    "data": {
                        "return_id": return_order.id,
                        "return_number": return_order.return_number,
                        "shiprocket_order_id":
                            return_order.shiprocket_order_id,
                        "shipment_id": return_order.shipment_id,
                        "awb_code": return_order.awb_code,
                        "courier_company":
                            return_order.courier_company,
                        "status": return_order.status
                    }
                },
                status=status.HTTP_200_OK
            )

        # =====================================================
        # ORIGINAL ORDER
        # =====================================================

        order = return_order.order

        if order.status != "DELIVERED":
            return Response(
                {
                    "success": False,
                    "message": "Only delivered orders can be returned.",
                    "current_status": order.status
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        product = order.product
        company = order.company
        customer = order.address

        if not company.pincode:
            return Response(
                {
                    "success": False,
                    "message": "Company pincode is missing."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not customer.pincode:
            return Response(
                {
                    "success": False,
                    "message": "Customer pincode is missing."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not company.pickup_location:
            return Response(
                {
                    "success": False,
                    "message": "Company pickup_location is missing."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # PRODUCT DIMENSIONS
        # =====================================================

        try:
            length = float(str(product.length).split()[0])
            breadth = float(str(product.width).split()[0])
            height = float(str(product.height).split()[0])
            weight = float(str(product.weight).split()[0])

            if min(length, breadth, height, weight) <= 0:
                raise ValueError(
                    "Dimensions and weight must be greater than zero."
                )

        except (ValueError, TypeError, IndexError) as exc:
            return Response(
                {
                    "success": False,
                    "message": f"Invalid product dimensions/weight: {exc}"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # PRICE
        # =====================================================

        try:
            price = Decimal(
                str(
                    product.final_price
                    if product.final_price
                    else product.price
                )
            )
            refund_amount = Decimal(str(return_order.refund_amount))

        except (InvalidOperation, TypeError, ValueError):
            return Response(
                {
                    "success": False,
                    "message": "Invalid product price or refund amount."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # SHIPROCKET VALID RETURN REASON
        # =====================================================

        reason_text = str(return_order.reason or "").strip().lower()

        reason_mapping = {
            "size issue": "size not as expected",
            "wrong size": "size not as expected",
            "size/quantity issue": "size or quantity issues",
            "not fit": "does not fit",
            "does not fit": "does not fit",
            "damaged": "item is damaged",
            "product damaged": "product damaged",
            "wrong item": "received wrong item",
            "wrong product": "received wrong item",
            "defective": "item defective",
            "quality issue": "quality not as expected",
            "quality problem": "quality not as expected",
            "changed mind": "changed my mind",
            "no longer needed": "no longer needed",
            "late delivery": "arrived too late",
            "not as described": "not as described",
            "other": "other",
        }

        shiprocket_reason = reason_mapping.get(
            reason_text,
            reason_text
        )

        valid_reasons = {
            "bought by mistake",
            "better price available",
            "performance or quality not adequate",
            "incompatible or not useful",
            "product damaged, but shipping box ok",
            "item arrived too late",
            "missing parts or accessories",
            "both product and shipping box damaged",
            "wrong item was sent",
            "item defective or doesn't work",
            "no longer needed",
            "didn't approve purchase",
            "inaccurate website description",
            "return against replacement",
            "delay refund",
            "delivered late",
            "product does not match description on website",
            "both product & outer box damaged",
            "defective or does not work",
            "product damaged",
            "but outer box damaged",
            "incorrect item delivered",
            "product defective or doesn't work",
            "product performance/quality is not up to my expectations",
            "other",
            "changed my mind",
            "does not fit",
            "size not as expected",
            "item is damaged",
            "received wrong item",
            "parcel damaged on arrival",
            "quality not as expected",
            "missing item or accessories",
            "performance not adequate",
            "not as described",
            "arrived too late",
            "order not received",
            "empty package",
            "wrong item or wrong colour was sent",
            "items or parts missing",
            "size or quantity issues",
            "status as delivered but order not received",
            "n/a",
        }

        # Shiprocket reason list मध्ये नसेल तर valid fallback वापरा.
        if shiprocket_reason not in valid_reasons:
            shiprocket_reason = "other"

        # =====================================================
        # SHIPROCKET PAYLOAD
        # =====================================================

        return_number = return_order.return_number

        payload = {
            "order_id": return_number,
            "order_date": return_order.created_at.strftime(
                "%Y-%m-%d %H:%M"
            ),

            # Pickup = Customer
            "pickup_customer_name": customer.full_name,
            "pickup_last_name": "",
            "pickup_address": customer.address_line1,
            "pickup_address_2": customer.address_line2 or "",
            "pickup_city": customer.city,
            "pickup_state": customer.state,
            "pickup_country": customer.country or "India",
            "pickup_pincode": customer.pincode,
            "pickup_email": user.email or "",
            "pickup_phone": customer.mobile_no,

            # Return destination = Company
            "shipping_customer_name": company.name,
            "shipping_last_name": "",
            "shipping_address": company.address or "",
            "shipping_address_2": "",
            "shipping_city": company.taluka or company.district or "",
            "shipping_state": company.state or "",
            "shipping_country": "India",
            "shipping_pincode": company.pincode,
            "shipping_email": company.email or "",
            "shipping_phone": company.phone_number or "",

            # Product
            "order_items": [
                {
                    "name": product.name,
                    "sku": product.product_code or str(product.id),
                    "units": return_order.quantity,
                    "selling_price": str(price),
                }
            ],

            # Payment
            "payment_method": order.payment_method,
            "sub_total": str(refund_amount),

            # Dimensions
            "length": length,
            "breadth": breadth,
            "height": height,
            "weight": weight,

            # Return reason must match Shiprocket's accepted values
            "return_reason": shiprocket_reason,
            "return_reason_note": return_order.reason_note or "",
        }

        print("RETURN SHIPROCKET PAYLOAD:", payload)

        # =====================================================
        # CREATE RETURN SHIPMENT
        # =====================================================

        try:
            response = ShiprocketService.create_return_shipment(payload)
        except Exception as exc:
            print("SHIPROCKET RETURN ERROR:", str(exc))

            return Response(
                {
                    "success": False,
                    "message": "Shiprocket return shipment request failed.",
                    "error": str(exc)
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        print("SHIPROCKET RETURN RESPONSE:", response)

        if not isinstance(response, dict) or not response.get("success"):
            return Response(
                {
                    "success": False,
                    "message": "Shiprocket return shipment creation failed.",
                    "shiprocket_response": response
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # EXTRACT THE REAL SHIPROCKET PAYLOAD
        # =====================================================
        #
        # Expected service response example:
        # {
        #   "success": True,
        #   "data": {
        #       "status": 1,
        #       "payload": {
        #           "order_id": 1671284055,
        #           "shipment_id": 1666934900,
        #           "awb_code": "1504877691654",
        #           "courier_name": "Delhivery Reverse Surface 5kg"
        #       }
        #   }
        # }
        #
        # =====================================================

        service_data = response.get("data") or {}

        # Support both wrapped and direct response structures.
        if isinstance(service_data, dict):
            shipment_data = (
                service_data.get("payload")
                or service_data.get("data")
                or service_data
            )
        else:
            shipment_data = {}

        # Some services return Shiprocket response at the top level.
        if not shipment_data.get("shipment_id"):
            outer_payload = response.get("payload") or {}
            if outer_payload.get("shipment_id"):
                shipment_data = outer_payload

        # =====================================================
        # CHECK SHIPROCKET STATUS AND IDS
        # =====================================================

        shiprocket_status = service_data.get("status")

        if shiprocket_status is None:
            shiprocket_status = response.get("status")

        # Shiprocket status=0 indicates failure.
        if str(shiprocket_status) == "0":
            return Response(
                {
                    "success": False,
                    "message": "Shiprocket did not create the return shipment.",
                    "shiprocket_response": response
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        shiprocket_order_id = shipment_data.get("order_id")
        shipment_id = shipment_data.get("shipment_id")
        awb_code = shipment_data.get("awb_code")
        courier_name = shipment_data.get("courier_name")

        if not shiprocket_order_id or not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Shiprocket response is missing order_id or shipment_id. "
                        "Database was not updated."
                    ),
                    "shiprocket_response": response
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        # =====================================================
        # SAVE VALUES TO DATABASE
        # =====================================================

        try:
            with transaction.atomic():
                return_order.shiprocket_order_id = str(shiprocket_order_id)
                return_order.shipment_id = str(shipment_id)
                return_order.awb_code = str(awb_code or "")
                return_order.courier_company = str(courier_name or "")
                return_order.status = "SHIPMENT_CREATED"

                return_order.save(
                    update_fields=[
                        "shiprocket_order_id",
                        "shipment_id",
                        "awb_code",
                        "courier_company",
                        "status",
                        "updated_at",
                    ]
                )

        except Exception as exc:
            print("RETURN ORDER DATABASE SAVE ERROR:", str(exc))

            return Response(
                {
                    "success": False,
                    "message": (
                        "Shiprocket created the shipment, but saving "
                        "the details to the database failed."
                    ),
                    "shiprocket_order_id": str(shiprocket_order_id),
                    "shipment_id": str(shipment_id),
                    "awb_code": str(awb_code or ""),
                    "error": str(exc)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Verify saved database values.
        return_order.refresh_from_db()

        # =====================================================
        # SUCCESS RESPONSE
        # =====================================================

        return Response(
            {
                "success": True,
                "message": "Return shipment created and saved successfully.",
                "data": {
                    "return_id": return_order.id,
                    "return_number": return_order.return_number,
                    "shiprocket_order_id": return_order.shiprocket_order_id,
                    "shipment_id": return_order.shipment_id,
                    "awb_code": return_order.awb_code,
                    "courier_company": return_order.courier_company,
                    "status": return_order.status,
                },
                "shiprocket_response": response,
            },
            status=status.HTTP_201_CREATED
        )


from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import ReturnOrder


class ReturnShiprocketOrderListAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        try:
            # Login केलेल्या user चे return orders
            return_orders = (
                ReturnOrder.objects
                .filter(order__user=request.user)
                .select_related(
                    "order",
                    "order__product",
                    "order__company",
                    "order__address"
                )
                .order_by("-created_at")
            )

            data = []

            for return_order in return_orders:

                order = return_order.order
                product = order.product

                data.append({
                    "return_id": return_order.id,
                    "return_number": return_order.return_number,

                    # Original order details
                    "order_id": order.id,
                    "order_status": order.status,
                    "payment_method": order.payment_method,

                    # Product details
                    "product_id": product.id if product else None,
                    "product_name": product.name if product else None,

                    # Return details
                    "quantity": return_order.quantity,
                    "reason": return_order.reason,
                    "reason_note": getattr(
                        return_order,
                        "reason_note",
                        ""
                    ),
                    "refund_amount": str(
                        return_order.refund_amount
                    ) if return_order.refund_amount is not None else None,

                    # Shiprocket details
                    "shiprocket_order_id": (
                        return_order.shiprocket_order_id
                    ),
                    "shipment_id": return_order.shipment_id,
                    "awb_code": return_order.awb_code,
                    "courier_company": return_order.courier_company,
                    "status": return_order.status,

                    # Date/time
                    "created_at": (
                        return_order.created_at.isoformat()
                        if return_order.created_at else None
                    ),
                    "updated_at": (
                        return_order.updated_at.isoformat()
                        if getattr(
                            return_order,
                            "updated_at",
                            None
                        ) else None
                    ),
                })

            return Response(
                {
                    "success": True,
                    "message": "Return shipment list fetched successfully.",
                    "count": len(data),
                    "data": data
                },
                status=status.HTTP_200_OK
            )

        except Exception as exc:
            return Response(
                {
                    "success": False,
                    "message": "Failed to fetch return shipment list.",
                    "error": str(exc)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        
import re

from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from state.services.shiprocket import ShiprocketService

# तुझ्या actual app मधून import कर:
# from your_app.models import ReturnOrder


class AssignReturnAWBAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        return_id = request.data.get("return_id")

        if not return_id:
            return Response(
                {
                    "success": False,
                    "message": "return_id is required.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            return_order = ReturnOrder.objects.select_related(
                "order"
            ).get(
                id=return_id,
                order__user=request.user,
            )

        except ReturnOrder.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Return order not found.",
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        # ------------------------------------------
        # 1. AWB आधीच database मध्ये असेल तर तोच द्या
        # ------------------------------------------
        if return_order.awb_code:
            return Response(
                {
                    "success": True,
                    "message": "Return AWB already assigned.",
                    "data": {
                        "return_id": return_order.id,
                        "return_number": return_order.return_number,
                        "shipment_id": return_order.shipment_id,
                        "awb_code": return_order.awb_code,
                        "courier_company": return_order.courier_company,
                        "status": return_order.status,
                    },
                },
                status=status.HTTP_200_OK,
            )

        if not return_order.shipment_id:
            return Response(
                {
                    "success": False,
                    "message": (
                        "shipment_id is missing. "
                        "Create the return shipment first."
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ------------------------------------------
        # 2. Shiprocket AWB assignment
        # ------------------------------------------
        try:
            response_data = ShiprocketService.assign_return_awb(
                shipment_id=return_order.shipment_id
            )

        except Exception as exc:
            return Response(
                {
                    "success": False,
                    "message": "Shiprocket AWB assignment request failed.",
                    "error": str(exc),
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        shiprocket_data = response_data.get("data", {})

        # Response structure can vary by Shiprocket response.
        nested_data = (
            shiprocket_data.get("response", {}).get("data", {})
        )

        awb_code = (
            shiprocket_data.get("awb_code")
            or shiprocket_data.get("response", {}).get("awb_code")
            or nested_data.get("awb_code")
        )

        courier_company = (
            shiprocket_data.get("courier_name")
            or shiprocket_data.get("response", {}).get("courier_name")
            or nested_data.get("courier_name")
        )

        # ------------------------------------------
        # 3. Already assigned AWB error handle करा
        # Example:
        # AWB is already assigned with awb - 1504877691654
        # and status - PICKUP GENERATED
        # ------------------------------------------
        error_message = (
            nested_data.get("awb_assign_error")
            or shiprocket_data.get("message")
            or response_data.get("message")
            or ""
        )

        if not awb_code and "already assigned" in error_message.lower():

            match = re.search(
                r"awb\s*-\s*([A-Za-z0-9]+)",
                error_message,
                re.IGNORECASE,
            )

            if match:
                awb_code = match.group(1)

        # ------------------------------------------
        # 4. AWB उपलब्ध असल्यास database मध्ये save करा
        # ------------------------------------------
        if awb_code:

            with transaction.atomic():

                return_order.awb_code = str(awb_code)

                if courier_company:
                    return_order.courier_company = courier_company
                elif not return_order.courier_company:
                    # Known courier ID from the supplied response.
                    if str(nested_data.get("courier_id", "")) == "138":
                        return_order.courier_company = (
                            "Delhivery Reverse Surface 5kg"
                        )

                # तुझ्या model मध्ये valid status choices असतील,
                # तर त्यातील योग्य status वापर.
                # Existing status आधीच PICKUP GENERATED असल्यास
                # तो overwrite करण्याची गरज नाही.
                current_status = str(
                    return_order.status or ""
                ).upper()

                if not current_status or current_status in {
                    "PENDING",
                    "CREATED",
                    "SHIPMENT_CREATED",
                }:
                    return_order.status = "PICKUP_PENDING"

                return_order.save(
                    update_fields=[
                        "awb_code",
                        "courier_company",
                        "status",
                    ]
                )

            return Response(
                {
                    "success": True,
                    "message": (
                        "Return AWB is available and saved successfully."
                    ),
                    "data": {
                        "return_id": return_order.id,
                        "return_number": return_order.return_number,
                        "shipment_id": return_order.shipment_id,
                        "awb_code": return_order.awb_code,
                        "courier_company": return_order.courier_company,
                        "status": return_order.status,
                    },
                    "shiprocket": response_data,
                },
                status=status.HTTP_200_OK,
            )

        # ------------------------------------------
        # 5. AWB मिळाला नाही तर error द्या
        # ------------------------------------------
        return Response(
            {
                "success": False,
                "message": "Return AWB assignment failed.",
                "shiprocket": response_data,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
        
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from django.db import transaction

from .models import ReturnOrder
from state.services.shiprocket import ShiprocketService


class ReturnPickupRequestAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):

        return_id = request.data.get("return_id")

        # 1. Validate return_id
        if not return_id:
            return Response(
                {
                    "success": False,
                    "message": "return_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 2. Get return order for logged-in user
        try:
            return_order = (
                ReturnOrder.objects
                .select_for_update()
                .select_related("order")
                .get(
                    id=return_id,
                    order__user=request.user
                )
            )

        except ReturnOrder.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Return order not found "
                        "or you do not have permission."
                    )
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # 3. Validate shipment ID
        shipment_id = getattr(
            return_order,
            "shipment_id",
            None
        )

        if not shipment_id:
            return Response(
                {
                    "success": False,
                    "message": (
                        "shipment_id is missing. "
                        "Please assign return AWB first."
                    ),
                    "data": {
                        "return_id": return_order.id,
                        "return_number": getattr(
                            return_order,
                            "return_number",
                            None
                        )
                    }
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 4. Validate return AWB
        awb_code = getattr(
            return_order,
            "awb_code",
            None
        )

        if not awb_code:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Return AWB is not assigned. "
                        "Please assign AWB first."
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 5. Send pickup request to Shiprocket
        result = ShiprocketService.request_return_pickup(
            shipment_id=shipment_id
        )

        if not result.get("success"):
            return Response(
                {
                    "success": False,
                    "message": "Shiprocket pickup request failed.",
                    "source": "shiprocket_api",
                    "data": result.get("data"),
                    "error": result.get("error")
                },
                status=(
                    status.HTTP_502_BAD_GATEWAY
                    if result.get("status_code") == 502
                    else status.HTTP_400_BAD_REQUEST
                )
            )

        # 6. Save pickup status only if the model has this field.
        # Do not mark the return as PICKED_UP here.
        already_queued = result.get("already_queued", False)

        if hasattr(return_order, "pickup_status"):
            return_order.pickup_status = (
                "Already in Pickup Queue"
                if already_queued
                else "Requested"
            )
            return_order.save(
                update_fields=["pickup_status"]
            )

        # 7. Return success response
        return Response(
            {
                "success": True,
                "message": (
                    "Pickup request is already in the "
                    "Shiprocket queue."
                    if already_queued
                    else "Return pickup request submitted successfully."
                ),
                "data": {
                    "return_id": return_order.id,
                    "return_number": getattr(
                        return_order,
                        "return_number",
                        None
                    ),
                    "shipment_id": str(shipment_id),
                    "awb_code": str(awb_code),
                    "pickup_status": (
                        "Already in Pickup Queue"
                        if already_queued
                        else "Requested"
                    ),
                    "shiprocket_response": result.get("data")
                }
            },
            status=status.HTTP_200_OK
        )
class TrackReturnShipmentAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        return_id = request.data.get(
            "return_id"
        )

        if not return_id:

            return Response(
                {
                    "success": False,
                    "message": "return_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # GET RETURN
        # =====================================================

        try:

            return_order = ReturnOrder.objects.select_related(
                "order"
            ).get(
                id=return_id,
                order__user=request.user
            )

        except ReturnOrder.DoesNotExist:

            return Response(
                {
                    "success": False,
                    "message": "Return order not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # =====================================================
        # SHIPMENT ID
        # =====================================================

        if not return_order.shipment_id:

            return Response(
                {
                    "success": False,
                    "message": "Return shipment ID not found."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # =====================================================
        # TRACK SHIPMENT
        # =====================================================

        response = (
            ShiprocketService.track_return_shipment(
                return_order.shipment_id
            )
        )

        print("RETURN TRACK RESPONSE:")
        print(response)

        if not response.get("success"):

            return Response(
                {
                    "success": False,
                    "message": (
                        "Unable to track return shipment."
                    ),
                    "shiprocket": response
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        data = response.get(
            "data",
            {}
        )

        # =====================================================
        # SAVE TRACKING
        # =====================================================

        return_order.tracking_data = data

        # =====================================================
        # STATUS DETECTION
        # =====================================================

        tracking_status = ""

        try:

            tracking_data = (
                data.get("tracking_data", {})
            )

            shipment_track = (
                tracking_data.get(
                    "shipment_track",
                    []
                )
            )

            if shipment_track:

                tracking_status = (
                    shipment_track[0].get(
                        "current_status",
                        ""
                    )
                )

        except Exception:

            tracking_status = ""

        # =====================================================
        # LOCAL STATUS
        # =====================================================

        if tracking_status:

            status_upper = (
                tracking_status.upper()
            )

            if "DELIVERED" in status_upper:

                return_order.status = (
                    "RECEIVED"
                )

            elif "TRANSIT" in status_upper:

                return_order.status = (
                    "IN_TRANSIT"
                )

            elif "PICKED" in status_upper:

                return_order.status = (
                    "PICKED_UP"
                )

        return_order.save()

        # =====================================================
        # RESPONSE
        # =====================================================

        return Response(
            {
                "success": True,

                "message":
                    "Return shipment tracked successfully.",

                "data": {

                    "return_id":
                        return_order.id,

                    "return_number":
                        return_order.return_number,

                    "shipment_id":
                        return_order.shipment_id,

                    "awb_code":
                        return_order.awb_code,

                    "courier_company":
                        return_order.courier_company,

                    "status":
                        return_order.status,

                    "tracking_status":
                        tracking_status,

                    "tracking_data":
                        data
                }
            }
        )        
        
        
        
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication

from .models import ShipOrder

from .models import PackingVideo
from .serializers import PackingVideoSerializer
from .s3_upload import upload_video_to_s3


class PackingVideoCreateAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):

        try:
            # ==============================
            # ORDER ID
            # ==============================

            order_id = request.data.get("order")

            if not order_id:
                return Response(
                    {
                        "success": False,
                        "message": "Order ID is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==============================
            # CHECK ORDER
            # ==============================

            try:
                order = ShipOrder.objects.get(
                    id=order_id
                )
            except ShipOrder.DoesNotExist:
                return Response(
                    {
                        "success": False,
                        "message": "Order not found."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ==============================
            # GET VIDEO
            # ==============================

            video = request.FILES.get("video")

            if not video:
                return Response(
                    {
                        "success": False,
                        "message": "Packing video is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==============================
            # VIDEO TYPE VALIDATION
            # ==============================

            allowed_types = [
                "video/mp4",
                "video/mpeg",
                "video/quicktime",
                "video/x-msvideo",
                "video/webm",
            ]

            if video.content_type not in allowed_types:
                return Response(
                    {
                        "success": False,
                        "message": (
                            "Invalid video format. "
                            "Allowed formats: MP4, MPEG, MOV, AVI, WEBM."
                        )
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==============================
            # VIDEO SIZE
            # Maximum 200 MB
            # ==============================

            max_size = 500 * 1024 * 1024

            if video.size > max_size:
                return Response(
                    {
                        "success": False,
                        "message": "Video size cannot exceed 200 MB."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==============================
            # UPLOAD TO S3
            # ==============================

            video_url = upload_video_to_s3(
                video,
                folder=f"packing-videos/{order.order_number}"
            )

            # ==============================
            # SAVE DATABASE
            # ==============================

            packing_video = PackingVideo.objects.create(
                order=order,
                uploaded_by=request.user,
                s3_video=video_url
            )

            # ==============================
            # SERIALIZER
            # ==============================

            serializer = PackingVideoSerializer(
                packing_video
            )

            return Response(
                {
                    "success": True,
                    "message": "Packing video uploaded successfully.",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to upload packing video.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )        
            
class PackingVideoRetrieveAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):

        try:

            # ==============================
            # GET ORDER ID
            # ==============================

            order_id = request.data.get("order_id")

            if not order_id:
                return Response(
                    {
                        "success": False,
                        "message": "Order ID is required."
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ==============================
            # GET LATEST PACKING VIDEO
            # ==============================

            packing_video = PackingVideo.objects.filter(
                order_id=order_id
            ).select_related(
                "order",
                "uploaded_by"
            ).order_by(
                "-id"
            ).first()

            if not packing_video:
                return Response(
                    {
                        "success": False,
                        "message": "Packing video not found for this order."
                    },
                    status=status.HTTP_404_NOT_FOUND
                )

            # ==============================
            # SERIALIZER
            # ==============================

            serializer = PackingVideoSerializer(
                packing_video
            )

            return Response(
                {
                    "success": True,
                    "message": "Packing video retrieved successfully.",
                    "data": serializer.data
                },
                status=status.HTTP_200_OK
            )

        except Exception as e:

            return Response(
                {
                    "success": False,
                    "message": "Failed to retrieve packing video.",
                    "error": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
            




class ShippingRateLocationAPIView(APIView):

    def post(self, request):

        pickup_postcode = request.data.get("pickup_postcode")
        delivery_postcode = request.data.get("delivery_postcode")
        weight = request.data.get("weight")
        length = request.data.get("length")
        breadth = request.data.get("breadth")
        height = request.data.get("height")
        payment_method = request.data.get("payment_method")
        declared_value = request.data.get("declared_value")

        # ==========================================
        # VALIDATION
        # ==========================================

        required_fields = {
            "pickup_postcode": pickup_postcode,
            "delivery_postcode": delivery_postcode,
            "weight": weight,
            "length": length,
            "breadth": breadth,
            "height": height,
            "payment_method": payment_method,
            "declared_value": declared_value,
        }

        missing_fields = [
            field
            for field, value in required_fields.items()
            if value is None or value == ""
        ]

        if missing_fields:
            return Response(
                {
                    "success": False,
                    "message": "Required fields are missing.",
                    "missing_fields": missing_fields,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ==========================================
        # PAYMENT METHOD VALIDATION
        # ==========================================

        payment_method = str(payment_method).strip().upper()

        if payment_method not in ["COD", "PREPAID"]:
            return Response(
                {
                    "success": False,
                    "message": "payment_method must be COD or PREPAID.",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        cod = 1 if payment_method == "COD" else 0

        # ==========================================
        # FETCH SHIPROCKET SHIPPING RATES
        # ==========================================

        try:
            data = get_shipping_rates(
                pickup_postcode=pickup_postcode,
                delivery_postcode=delivery_postcode,
                weight=weight,
                length=length,
                breadth=breadth,
                height=height,
                cod=cod,
                declared_value=declared_value,
            )

            courier_data = (
                data.get("data", {})
                .get("available_courier_companies", [])
            )

            # ==========================================
            # FILTER SURFACE COURIERS ONLY
            # ==========================================

            surface_couriers = [
                courier
                for courier in courier_data
                if "surface" in str(
                    courier.get("courier_name", "")
                ).lower()
                and courier.get("rate") is not None
            ]

            if not surface_couriers:
                return Response(
                    {
                        "success": False,
                        "message": "No Surface courier available for this route.",
                        "courier": None,
                    },
                    status=status.HTTP_200_OK,
                )

            # ==========================================
            # SELECT LOWEST RATE SURFACE COURIER
            # ==========================================

            best_courier = min(
                surface_couriers,
                key=lambda courier: float(courier["rate"]),
            )

            # ==========================================
            # SINGLE COURIER RESPONSE
            # ==========================================

            courier_response = {
                "courier_id": best_courier.get(
                    "courier_company_id"
                ),
                "courier_name": best_courier.get(
                    "courier_name"
                ),
                "rate": best_courier.get("rate"),
                "freight_charge": best_courier.get(
                    "freight_charge"
                ),
                "cod_charges": best_courier.get(
                    "cod_charges"
                ),
                "estimated_delivery_days": best_courier.get(
                    "estimated_delivery_days"
                ),
                "etd": best_courier.get("etd"),
                "rating": best_courier.get("rating"),
            }

            return Response(
                {
                    "success": True,
                    "message": "Surface shipping rate fetched successfully.",
                    "payment_method": payment_method,
                    "courier": courier_response,
                },
                status=status.HTTP_200_OK,
            )

        except requests.exceptions.RequestException:
            return Response(
                {
                    "success": False,
                    "message": (
                        "Unable to connect to Shiprocket or fetch rates."
                    ),
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        except (TypeError, ValueError):
            return Response(
                {
                    "success": False,
                    "message": "Invalid shipping rate returned by Shiprocket.",
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        except Exception as e:
            return Response(
                {
                    "success": False,
                    "message": "Unable to fetch shipping rates.",
                    "error": str(e),
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
            
            
            


import secrets
import logging

from django.conf import settings
from django.db import transaction
from django.db.models import Q

from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from .models import ShipOrder


logger = logging.getLogger(__name__)


class ShiprocketWebhookAPIView(APIView):

    # --------------------------------------------------
    # WEBHOOK IS PUBLIC
    # AUTHENTICATION IS DONE USING x-api-key
    # --------------------------------------------------

    authentication_classes = []
    permission_classes = [AllowAny]

    @transaction.atomic
    def post(self, request):

        # ==================================================
        # 1. VERIFY WEBHOOK TOKEN
        # ==================================================

        expected_token = getattr(
            settings,
            "SHIPROCKET_WEBHOOK_TOKEN",
            ""
        )

        expected_token = str(
            expected_token
        ).strip()

        received_token = request.headers.get(
            "x-api-key",
            ""
        )

        received_token = str(
            received_token
        ).strip()

        # ----------------------------------------------
        # Invalid token
        # ----------------------------------------------

        if (
            not expected_token
            or not received_token
            or not secrets.compare_digest(
                received_token,
                expected_token
            )
        ):

            logger.warning(
                "Invalid Shiprocket webhook authentication"
            )

            return Response(
                {
                    "success": False,
                    "message": "Invalid webhook token"
                },
                status=status.HTTP_401_UNAUTHORIZED
            )

        # ==================================================
        # 2. READ REQUEST PAYLOAD
        # ==================================================

        payload = request.data

        logger.info(
            "Shiprocket webhook received"
        )

        logger.info(
            "Webhook payload: %s",
            payload
        )

        # ----------------------------------------------
        # Payload must be dictionary
        # ----------------------------------------------

        if not isinstance(payload, dict):

            logger.warning(
                "Invalid webhook payload format"
            )

            return Response(
                {
                    "success": True,
                    "message": "Webhook received."
                },
                status=status.HTTP_200_OK
            )

        # ==================================================
        # 3. HANDLE NESTED DATA
        # ==================================================

        data = payload

        nested_data = payload.get(
            "data"
        )

        if isinstance(
            nested_data,
            dict
        ):

            data = {
                **payload,
                **nested_data
            }

        logger.info(
            "Processed webhook data: %s",
            data
        )

        # ==================================================
        # 4. EXTRACT ORDER REFERENCE
        # ==================================================

        order_reference = (
            data.get("channel_order_id")
            or data.get("channel_order_number")
            or data.get("order_number")
            or data.get("order_id")
        )

        # Convert to string
        if order_reference is not None:

            order_reference = str(
                order_reference
            ).strip()

        # ==================================================
        # 5. EXTRACT SHIPROCKET ORDER ID
        # ==================================================

        shiprocket_order_id = (
            data.get("sr_order_id")
            or data.get("shiprocket_order_id")
            or data.get("shipment_order_id")
        )

        if shiprocket_order_id is not None:

            shiprocket_order_id = str(
                shiprocket_order_id
            ).strip()

        # ==================================================
        # 6. EXTRACT AWB
        # ==================================================

        awb_code = (
            data.get("awb")
            or data.get("awb_code")
            or data.get("awb_number")
        )

        if awb_code is not None:

            awb_code = str(
                awb_code
            ).strip()

        # ==================================================
        # 7. EXTRACT COURIER
        # ==================================================

        courier_name = (
            data.get("courier_name")
            or data.get("courier_company")
            or data.get("courier")
        )

        if courier_name is not None:

            courier_name = str(
                courier_name
            ).strip()

        # ==================================================
        # 8. EXTRACT CURRENT STATUS
        # ==================================================

        current_status = (
            data.get("current_status")
            or data.get("shipment_status")
            or data.get("status")
        )

        # --------------------------------------------------
        # Sometimes status can be nested
        # --------------------------------------------------

        if not current_status:

            shipment_data = data.get(
                "shipment"
            )

            if isinstance(
                shipment_data,
                dict
            ):

                current_status = (
                    shipment_data.get(
                        "current_status"
                    )
                    or shipment_data.get(
                        "shipment_status"
                    )
                    or shipment_data.get(
                        "status"
                    )
                )

        # ==================================================
        # 9. IF STATUS MISSING
        # ==================================================

        if not current_status:

            logger.warning(
                "Webhook received but shipment status is missing."
            )

            return Response(
                {
                    "success": True,
                    "message": "Webhook received, but shipment status is missing."
                },
                status=status.HTTP_200_OK
            )

        # ==================================================
        # 10. NORMALIZE STATUS
        # ==================================================

        shiprocket_status = str(
            current_status
        ).strip().upper()

        shiprocket_status = (
            shiprocket_status
            .replace("_", " ")
            .replace("-", " ")
        )

        # ==================================================
        # 11. STATUS MAPPING
        # ==================================================

        status_map = {

            # ------------------------------------------
            # Pending
            # ------------------------------------------

            "NEW": "PENDING",
            "PENDING": "PENDING",

            # ------------------------------------------
            # Confirmed
            # ------------------------------------------

            "CONFIRMED": "CONFIRMED",
            "ORDER CONFIRMED": "CONFIRMED",
            "INVOICED": "CONFIRMED",

            # ------------------------------------------
            # Packed
            # ------------------------------------------

            "READY TO SHIP": "PACKED",
            "READY TO SHIP ": "PACKED",
            "PACKED": "PACKED",
            "PICKUP SCHEDULED": "PACKED",
            "PICKUP GENERATED": "PACKED",
            "PICKUP QUEUED": "PACKED",

            # ------------------------------------------
            # Shipped
            # ------------------------------------------

            "SHIPPED": "SHIPPED",
            "PICKED UP": "SHIPPED",
            "IN TRANSIT": "SHIPPED",
            "DISPATCHED": "SHIPPED",

            # ------------------------------------------
            # Out For Delivery
            # ------------------------------------------

            "OUT FOR DELIVERY": "OUT_FOR_DELIVERY",

            # ------------------------------------------
            # Delivered
            # ------------------------------------------

            "DELIVERED": "DELIVERED",

            # ------------------------------------------
            # Cancelled
            # ------------------------------------------

            "CANCELLED": "CANCELLED",
            "CANCELED": "CANCELLED",
            "ORDER CANCELLED": "CANCELLED",
            "ORDER CANCELED": "CANCELLED",

            # ------------------------------------------
            # Return Requested
            # ------------------------------------------

            "RETURN PENDING": "RETURN_REQUESTED",
            "RETURN REQUESTED": "RETURN_REQUESTED",
            "RETURN INITIATED": "RETURN_REQUESTED",
            "RTO INITIATED": "RETURN_REQUESTED",

            # ------------------------------------------
            # Return Pickup
            # ------------------------------------------

            "RETURN PICKUP QUEUED": "RETURN_PICKUP",
            "RETURN PICKUP": "RETURN_PICKUP",
            "OUT FOR PICKUP": "RETURN_PICKUP",

            # ------------------------------------------
            # Return In Transit
            # ------------------------------------------

            "RETURN IN TRANSIT": "RETURN_IN_TRANSIT",
            "RTO IN TRANSIT": "RETURN_IN_TRANSIT",

            # ------------------------------------------
            # Returned
            # ------------------------------------------

            "RETURNED": "RETURNED",
            "RETURN DELIVERED": "RETURNED",
            "RTO DELIVERED": "RETURNED",
        }

        new_status = status_map.get(
            shiprocket_status
        )

        # ==================================================
        # 12. STATUS NOT MAPPED
        # ==================================================

        if not new_status:

            logger.warning(
                "Unmapped Shiprocket status: %s",
                shiprocket_status
            )

            return Response(
                {
                    "success": True,
                    "message": "Webhook received; status is not mapped.",
                    "shiprocket_status": shiprocket_status
                },
                status=status.HTTP_200_OK
            )

        # ==================================================
        # 13. FIND ORDER
        # ==================================================

        query = Q()

        # ------------------------------------------
        # QNX Mart order number
        # ------------------------------------------

        if order_reference:

            query |= Q(
                order_number=str(
                    order_reference
                )
            )

        # ------------------------------------------
        # Shiprocket order ID
        # ------------------------------------------

        if shiprocket_order_id:

            query |= Q(
                shipment__shiprocket_order_id=str(
                    shiprocket_order_id
                )
            )

        # ------------------------------------------
        # AWB
        # ------------------------------------------

        if awb_code:

            query |= Q(
                shipment__awb_code=str(
                    awb_code
                )
            )

        # ==================================================
        # 14. NO REFERENCE
        # ==================================================

        if not query:

            logger.warning(
                "Webhook has no order reference, "
                "Shiprocket order ID or AWB."
            )

            return Response(
                {
                    "success": True,
                    "message": "Webhook received; order reference is missing."
                },
                status=status.HTTP_200_OK
            )

        # ==================================================
        # 15. GET ORDER
        # ==================================================

        order = (
            ShipOrder.objects
            .select_for_update()
            .filter(query)
            .distinct()
            .first()
        )

        # ==================================================
        # 16. ORDER NOT FOUND
        # ==================================================

        if not order:

            logger.warning(
                "Matching ShipOrder not found. "
                "Order Reference=%s, "
                "Shiprocket Order ID=%s, "
                "AWB=%s",
                order_reference,
                shiprocket_order_id,
                awb_code
            )

            # ------------------------------------------
            # IMPORTANT
            # Return 200 to Shiprocket
            # ------------------------------------------

            return Response(
                {
                    "success": True,
                    "message": "Webhook received, but matching order was not found.",
                    "order_reference": order_reference,
                    "shiprocket_order_id": shiprocket_order_id,
                    "awb_code": awb_code
                },
                status=status.HTTP_200_OK
            )

        # ==================================================
        # 17. OLD STATUS
        # ==================================================

        old_status = order.status

        update_fields = []

        # ==================================================
        # 18. UPDATE STATUS
        # ==================================================

        if order.status != new_status:

            order.status = new_status

            update_fields.append(
                "status"
            )

        # ==================================================
        # 19. UPDATE COURIER
        # ==================================================

        if courier_name:

            if order.courier_name != courier_name:

                order.courier_name = courier_name

                update_fields.append(
                    "courier_name"
                )

        # ==================================================
        # 20. SAVE
        # ==================================================

        if update_fields:

            update_fields.append(
                "updated_at"
            )

            order.save(
                update_fields=update_fields
            )

        # ==================================================
        # 21. LOG
        # ==================================================

        logger.info(
            "QNX Mart order status synchronized | "
            "Order=%s | Old=%s | New=%s",
            order.order_number,
            old_status,
            order.status
        )

        # ==================================================
        # 22. SUCCESS RESPONSE
        # ==================================================

        return Response(
            {
                "success": True,
                "message": "Order status synchronized successfully.",
                "order_id": order.id,
                "order_number": order.order_number,
                "old_status": old_status,
                "new_status": order.status,
                "courier_name": order.courier_name
            },
            status=status.HTTP_200_OK
        )