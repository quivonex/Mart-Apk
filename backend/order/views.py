
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Order, OrderItem    
from rest_framework.permissions import IsAdminUser
from .serializers import OrderSerializer
from rest_framework import status
from .models import Order, OrderItem
from product.models import Product
import uuid
from collections import defaultdict
from .models import Address
from .serializers import AddressSerializer
from rest_framework.permissions import IsAuthenticated



from collections import defaultdict
from decimal import Decimal
import uuid
from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from collections import defaultdict
from decimal import Decimal
from django.db import transaction
from django.db.models import F
import uuid

class CreateOrderView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        data = request.data

        def get_field(*keys):
            for key in keys:
                if data.get(key):
                    return data.get(key)
            return None

        full_name = get_field('full_name', 'fullName')

        if not full_name:
            return Response({"status": "error", "message": "full_name is required"}, status=400)

        address_id = data.get('address')

        if not address_id:
            return Response({"status": "error", "message": "Address ID is required"}, status=400)

        try:
            address = Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response({"status": "error", "message": "Address not found"}, status=404)

        items = data.get('items', [])

        if not items:
            return Response({"status": "error", "message": "Order items required"}, status=400)

        company_items = defaultdict(list)

        # ---------------- VALIDATION ----------------
        for item in items:
            product_id = item.get('product')

            if not product_id:
                return Response({"status": "error", "message": "Product ID missing"}, status=400)

            try:
                product = Product.objects.get(id=product_id)
            except Product.DoesNotExist:
                return Response({"status": "error", "message": f"Product {product_id} not found"}, status=404)

            quantity = int(item.get('quantity', 1))

            if quantity <= 0:
                return Response({"status": "error", "message": "Quantity must be greater than 0"}, status=400)

            # 🔥 STOCK CHECK
            if product.stock_quantity < quantity:
                return Response({
                    "status": False,
                    "message": f"Not enough stock for {product.name}"
                }, status=400)

            company_items[product.company].append({
                "product": product,
                "quantity": quantity,
                "final_price": product.final_price
            })

        created_orders = []

        # ---------------- TRANSACTION ----------------
        with transaction.atomic():

            for company, items_list in company_items.items():

                order = Order.objects.create(
                    user=request.user,
                    company=company,
                    order_id="ORD-" + uuid.uuid4().hex[:10].upper(),
                    full_name=full_name,
                    address=address,
                    total_amount=sum(
                        Decimal(str(i['final_price'])) * i['quantity']
                        for i in items_list
                    ),
                    payment_method=get_field('payment_method', 'paymentMethod') or 'cod',
                    payment_status=data.get('payment_status', 'pending'),
                    status=data.get('status', 'placed')
                )

                for item in items_list:

                    product = item['product']
                    quantity = item['quantity']

                    OrderItem.objects.create(
                        order=order,
                        product=product,
                        quantity=quantity,
                        price=item['final_price']
                    )

                    # 🔥 SAFE STOCK UPDATE (BEST WAY)
                    Product.objects.filter(id=product.id).update(
                        stock_quantity=F('stock_quantity') - quantity
                    )

                created_orders.append(order)

        serializer = OrderSerializer(created_orders, many=True)

        return Response({
            "status": "success",
            "message": "Order created successfully",
            "orders": serializer.data
        }, status=201)
    
class OrderDetailView(APIView):

    def post(self, request):

        order_id = request.data.get('order_id')

        order = Order.objects.get(order_id=order_id)

        items = OrderItem.objects.filter(order=order)

        return Response({
            "order_id": order.order_id,
            "items": [
                {
                    "product": i.product.name,
                    "qty": i.quantity,
                    "price": i.price
                } for i in items
            ]
        })
    

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import Order

class AddressListView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user

        # 👇 ONLY FIRST 2 ADDRESSES
        orders = Order.objects.filter(user=user).order_by('-created_at')[:3]

        address_list = []

        for o in orders:
            address_list.append({
                "full_name": o.full_name,
                "phone": o.phone,
                "address_line_1": o.address_line_1,
                "address_line_2": o.address_line_2,
                "city": o.city,
                "state": o.state,
                "pincode": o.pincode
            })

        return Response({
            "status": "success",
            "addresses": address_list
        }) 



class AdminOrderListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user

        # current user's companies
        companies = user.companies.all()

        orders = Order.objects.filter(company__in=companies).order_by('-created_at')

        serializer = OrderSerializer(orders, many=True)
        return Response(serializer.data)




class CompanySalesAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        companies = request.user.companies.all()

        if not companies.exists():
            return Response({
                "status": "error",
                "message": "No company assigned"
            }, status=403)

        orders = Order.objects.filter(
            company__in=companies
        ).prefetch_related(
            'items__product'
        ).select_related('user', 'company').order_by('-created_at')

        serializer = OrderSerializer(orders, many=True)

        return Response({
            "status": "success",
            "data": serializer.data
        })
        
        

class AddressCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = AddressSerializer(
            data=request.data,
            context={'request': request}
        )

        if serializer.is_valid():
            serializer.save()

            return Response({
                "status": "success",
                "message": "Address created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": "error",
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
        
class AddressListView(APIView):
    permission_classes = [IsAuthenticated]

    def post    (self, request):
        addresses = Address.objects.filter(user=request.user).order_by('-created_at')
        serializer = AddressSerializer(addresses, many=True)

        return Response({
            "status": "success",
            "count": addresses.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)        
        
        


class AddressUpdateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        address_id = request.data.get("id")

        if not address_id:
            return Response({
                "status": "error",
                "message": "Address ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            address = Address.objects.get(id=address_id, user=request.user)
        except Address.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Address not found"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = AddressSerializer(
            address,
            data=request.data,
            partial=True,
            context={'request': request}
        )

        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": "success",
                "message": "Address updated successfully",
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        return Response({
            "status": "error",
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
        
        
from .services.shiprocket import get_shiprocket_token,calculate_shipping_rate,select_recommended_courier,create_order,assign_courier,schedule_pickup,generate_label,track_order,cancel_order
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from .models import Product, Company, Address
from .utils import parse_number, parse_weight


@api_view(['GET'])
@permission_classes([AllowAny])
def test_shiprocket(request):   
    data = get_shiprocket_token()
    return Response(data)



from collections import defaultdict


@api_view(['POST'])
@permission_classes([AllowAny])
def get_shipping_rates(request):

    data = request.data
    product_ids = data.get("product_ids", [])
    address_id = data.get("address_id")
    cod = int(data.get("cod", 0))

    if not product_ids:
        return Response({"error": "Product IDs are required"}, status=400)

    products = Product.objects.filter(id__in=product_ids)

    if not products.exists():
        return Response({"error": "Products not found"}, status=404)

    try:
        address = Address.objects.get(id=address_id)
    except Address.DoesNotExist:
        return Response({"error": "Address not found"}, status=404)

    # -----------------------------
    # GROUP PRODUCTS BY COMPANY
    # -----------------------------
    grouped_products = defaultdict(list)

    for product in products:
        grouped_products[product.company.id].append(product)

    shipment_results = []
    grand_total = 0

    for company_id, company_products in grouped_products.items():

        company = company_products[0].company

        total_weight = 0
        total_declared_value = 0
        max_length = 0
        max_width = 0
        total_height = 0

        for product in company_products:
            total_weight += parse_weight(product.weight)
            total_declared_value += float(product.final_price or product.price or 0)

            max_length = max(max_length, parse_number(product.lenghts, 10))
            max_width = max(max_width, parse_number(product.width, 10))
            total_height += parse_number(product.height, 5)

        payload = {
            "pickup_postcode": company.pincode,
            "delivery_postcode": address.pincode,
            "weight": total_weight,
            "length": max_length,
            "breadth": max_width,
            "height": total_height,
            "cod": cod,
            "declared_value": total_declared_value,
        }

        response = calculate_shipping_rate(payload)
        best_courier = select_recommended_courier(response)

        if not best_courier:
            continue

        base_charge = float(best_courier.get("rate", 0))
        gst_percent = 18
        gst_amount = round((base_charge * gst_percent) / 100, 2)
        total_charge = round(base_charge + gst_amount, 2)

        grand_total += total_charge

        shipment_results.append({
            "company": company.name,

            "pickup_postcode": company.pincode,
            "delivery_postcode": address.pincode,

            "weight": total_weight,
            "length": max_length,
            "breadth": max_width,
            "height": total_height,

            "courier_name": best_courier.get("courier_name"),
            "delivery_days": best_courier.get("estimated_delivery_days"),
            "courier_id": best_courier.get("courier_company_id"),

            "cod": cod,

            "base_shipping_charge": round(base_charge, 2),

            "gst_percent": gst_percent,
            "gst_amount": round(gst_amount, 2),

            "total_shipping_charge": round(total_charge, 2)
        })

    return Response({
        "shipments": shipment_results,
        "grand_total_shipping_charge": round(grand_total, 2)
    })
    
    
    
    
    
    
import time
import re
def get_numeric_value(value, default):
    if value is None:
        return default

    value = str(value).strip()

    match = re.search(r'(\d+(\.\d+)?)', value)

    if match:
        return float(match.group(1))

    return default
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_full_shiprocket_order(request):
    data = request.data

    product_id = data.get("product_id")
    address_id = data.get("address_id")
    courier_id = data.get("courier_id")
    quantity = int(data.get("quantity", 1))
    payment_method = data.get("payment_method", "cod")

    # -----------------------------
    # VALIDATION
    # -----------------------------
    if not product_id:
        return Response({"error": "product_id is required"}, status=400)

    if not address_id:
        return Response({"error": "address_id is required"}, status=400)

    if not courier_id:
        return Response({"error": "courier_id is required"}, status=400)

    # -----------------------------
    # PRODUCT
    # -----------------------------
    try:
        product = Product.objects.get(id=product_id)
    except Product.DoesNotExist:
        return Response({"error": "Product not found"}, status=404)

    # -----------------------------
    # ADDRESS
    # -----------------------------
    try:
        address = Address.objects.get(id=address_id)
    except Address.DoesNotExist:
        return Response({"error": "Address not found"}, status=404)

    # -----------------------------
    # NAME SPLIT FOR SHIPROCKET
    # -----------------------------
    name_parts = address.full_name.strip().split()
    first_name = name_parts[0]
    last_name = " ".join(name_parts[1:]) if len(name_parts) > 1 else "Customer"

    # -----------------------------
    # PRICE
    # -----------------------------
    product_price = float(product.final_price or product.price)
    sub_total = product_price * quantity

    # -----------------------------
    # GST
    # -----------------------------
    if product.GST_percent:
        gst_percent = float(product.GST_percent)

    elif product.HSN_code:
        gst_percent = product.get_gst_from_hsn()

    else:
        gst_percent = 0

    gst_amount = round((sub_total * gst_percent) / 100, 2)
    total_amount = round(sub_total + gst_amount, 2)

    # -----------------------------
    # CREATE LOCAL ORDER
    # -----------------------------
    order = Order.objects.create(
        user=request.user,
        company=product.company,
        order_id=f"ORD{int(time.time()*1000)}",
        full_name=address.full_name,
        address=address,
        total_amount=total_amount,
        payment_method=payment_method
    )

    # -----------------------------
    # CREATE ORDER ITEM
    # -----------------------------
    OrderItem.objects.create(
        order=order,
        product=product,
        quantity=quantity,
        price=product_price
    )

    # -----------------------------
    # SHIPROCKET PAYLOAD
    # -----------------------------
    order_payload = {
        "order_id": order.order_id,
        "order_date": str(order.created_at.date()),
        "pickup_location": "Home",

        "billing_customer_name": first_name,
        "billing_last_name": last_name,

        "billing_address": (
            f"{address.address_line1}, {address.address_line2}"
            if address.address_line2
            else address.address_line1
        ),

        "billing_city": address.city,
        "billing_pincode": address.pincode,
        "billing_state": address.state,
        "billing_country": address.country,
        "billing_phone": address.mobile_no,

        "shipping_is_billing": True,

        "order_items": [
            {
                "name": product.name,
                "sku": product.product_code or str(product.id),
                "units": quantity,
                "selling_price": product_price
            }
        ],

        "payment_method": "COD" if payment_method == "cod" else "Prepaid",

        "sub_total": sub_total,
        "shipping_charges": gst_amount,

        "length": get_numeric_value(product.lenghts, 10),
        "breadth": get_numeric_value(product.width, 10),
        "height": get_numeric_value(product.height, 10),
        "weight": get_numeric_value(product.weight, 0.5),
    }

   # -----------------------------
    # CREATE SHIPROCKET ORDER
    # -----------------------------
    order_response = create_order(order_payload)

    shipment_id = order_response.get("shipment_id")

    if not shipment_id:
        return Response({
            "status": False,
            "error": "Shiprocket order creation failed",
            "details": order_response
        }, status=400)

    # -----------------------------
    # TRY TO ASSIGN COURIER
    # -----------------------------
    assign_response = assign_courier(
        shipment_id,
        courier_id
    )

    # KYC not completed
    if assign_response.get("status_code") == 400:
        return Response({
            "status": True,
            "message": "Order created successfully. Courier assignment skipped because Shiprocket KYC is not completed.",
            "local_order_id": order.order_id,
            "shipment_id": shipment_id,
            "gst_percent": gst_percent,
            "gst_amount": gst_amount,
            "total_amount": total_amount,
            "shiprocket_order": order_response,
            "courier": assign_response,
            "label": None
        }, status=200)

    # -----------------------------
    # GET AWB
    # -----------------------------
    awb_code = (
        assign_response.get("response", {})
        .get("data", {})
        .get("awb_code")
    )

    if not awb_code:
        return Response({
            "status": False,
            "error": "Courier assign failed",
            "details": assign_response
        }, status=400)

    # -----------------------------
    # GENERATE LABEL
    # -----------------------------
    label_response = generate_label(shipment_id)

    return Response({
        "status": True,
        "message": "Order created successfully.",
        "local_order_id": order.order_id,
        "shipment_id": shipment_id,
        "awb_code": awb_code,
        "gst_percent": gst_percent,
        "gst_amount": gst_amount,
        "total_amount": total_amount,
        "shiprocket_order": order_response,
        "courier": assign_response,
        "label": label_response
    }, status=200)
        
    
    
@api_view(['Get'])
@permission_classes([IsAuthenticated])
def track_shipment(request):
    order_id = request.GET.get("order_id")

    if not order_id:
        return Response({"error": "order_id required"}, status=400)

    try:
        order = Order.objects.get(
            order_id=order_id,
            user=request.user
        )

        if not order.awb_code:
            return Response({
                "error": "Shipment not assigned yet"
            }, status=400)

        data = track_order(order.awb_code)

        return Response(data)

    except Order.DoesNotExist:
        return Response({
            "error": "Order not found"
        }, status=404)
        

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_shiprocket_order(request):
    custom_order_id = request.data.get("order_id")

    if not custom_order_id:
        return Response({
            "error": "order_id required"
        }, status=400)

    try:
        order = Order.objects.get(
            order_id=custom_order_id,
            user=request.user
        )

    except Order.DoesNotExist:
        return Response({
            "error": "Order not found"
        }, status=404)

    cancel_response = cancel_order(custom_order_id)

    if cancel_response.get("status_code") == 200:
        order.status = "cancelled"
        order.save()

        return Response({
            "message": "Order cancelled successfully",
            "order_id": custom_order_id
        })

    return Response({
        "error": "Order cancellation failed",
        "order_id": custom_order_id,
        "details": cancel_response
    }, status=400)
  
  
  
    
