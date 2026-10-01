from django.db import models
from accounts.models import User


from company.models import Company
from product.models import Product
from order.models import Address


class ShipOrder(models.Model):

    PAYMENT_CHOICES = (
        ("COD", "Cash On Delivery"),
        ("PREPAID", "Prepaid"),
    )

    STATUS_CHOICES = (
            ("PENDING", "Pending"),
            ("CONFIRMED", "Confirmed"),
            ("PACKED", "Packed"),
            ("SHIPPED", "Shipped"),
            ("OUT_FOR_DELIVERY", "Out For Delivery"),
            ("DELIVERED", "Delivered"),

            ("RETURN_REQUESTED", "Return Requested"),
            ("RETURN_PICKUP", "Return Pickup"),
            ("RETURN_IN_TRANSIT", "Return In Transit"),
            ("RETURNED", "Returned"),
            ("REFUNDED", "Refunded"),

            ("CANCELLED", "Cancelled"),
    )

    ORDER_SOURCE = (
        ("WEB", "Website"),
        ("APP", "Mobile App"),
    )

    order_number = models.CharField(max_length=50, unique=True)
    user = models.ForeignKey(User,on_delete=models.CASCADE,null=True,blank=True,related_name="shiporders")
    company = models.ForeignKey(Company,on_delete=models.CASCADE,related_name="shiporders")
    product = models.ForeignKey(Product,on_delete=models.CASCADE,related_name="shiporders")
    address = models.ForeignKey(Address,on_delete=models.PROTECT)
    quantity = models.PositiveIntegerField(default=1)
    payment_method = models.CharField(
        max_length=20,
        choices=PAYMENT_CHOICES
    )

    payment_status = models.BooleanField(default=False)

    subtotal = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    shipping_charge = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )
    courier_id = models.IntegerField(
    null=True,
    blank=True
   )

    courier_name = models.CharField(
        max_length=255,
        null=True,
        blank=True
    )

    tax_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )

    discount_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )

    total_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default="PENDING"
    )

    source = models.CharField(
        max_length=10,
        choices=ORDER_SOURCE,
        default="WEB"
    )

    notes = models.TextField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.order_number
    
    
class ShipOrderItem(models.Model):

    order = models.ForeignKey(
        ShipOrder,
        on_delete=models.CASCADE,
        related_name="itemss"
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE
    )

    quantity = models.PositiveIntegerField(default=1)

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    total = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.order.order_number} - {self.product.name}"    
    
    



class Shipment(models.Model):

    order = models.OneToOneField(
        ShipOrder,
        on_delete=models.CASCADE,
        related_name="shipment"
    )

    shiprocket_order_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    shipment_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    awb_code = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    courier_company = models.CharField(
        max_length=200,
        blank=True,
        null=True
    )

    tracking_url = models.URLField(
        blank=True,
        null=True
    )

    shipping_charge = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )
    label_url = models.URLField(
    blank=True,
    null=True
    )
    pickup_request_id = models.CharField(
    max_length=100,
    blank=True,
    null=True
    )

    pickup_status = models.CharField(
        max_length=100,
        default="Pending"
    )
    tracking_data = models.JSONField(
    blank=True,
    null=True
    )
    manifest_url = models.URLField(
    blank=True,
    null=True
    )

    status = models.CharField(
        max_length=50,
        default="Pending"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return str(self.order.order_number)
    
    

class ReturnOrder(models.Model):

    RETURN_REASON_CHOICES = (
        ("DAMAGED", "Product Damaged"),
        ("WRONG_PRODUCT", "Wrong Product"),
        ("DEFECTIVE", "Defective Product"),
        ("SIZE_ISSUE", "Size Issue"),
        ("QUALITY_ISSUE", "Quality Issue"),
        ("CUSTOMER_CHANGED_MIND", "Customer Changed Mind"),
        ("OTHER", "Other"),
    )

    STATUS_CHOICES = (
        ("REQUESTED", "Requested"),
        ("APPROVED", "Approved"),
        ("PICKUP_PENDING", "Pickup Pending"),
        ("PICKED_UP", "Picked Up"),
        ("IN_TRANSIT", "In Transit"),
        ("RECEIVED", "Received"),
        ("REFUNDED", "Refunded"),
        ("REJECTED", "Rejected"),
        ("CANCELLED", "Cancelled"),
    )

    return_number = models.CharField(
        max_length=50,
        unique=True
    )

    order = models.ForeignKey(
        ShipOrder,
        on_delete=models.PROTECT,
        related_name="return_orders"
    )

    quantity = models.PositiveIntegerField(default=1)

    reason = models.CharField(
        max_length=50,
        choices=RETURN_REASON_CHOICES
    )

    reason_note = models.TextField(
        blank=True,
        null=True
    )

    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default="REQUESTED"
    )

    # Shiprocket return shipment
    shiprocket_order_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    shipment_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    awb_code = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    courier_company = models.CharField(
        max_length=200,
        blank=True,
        null=True
    )

    tracking_url = models.URLField(
        blank=True,
        null=True
    )

    pickup_request_id = models.CharField(
        max_length=100,
        blank=True,
        null=True
    )

    pickup_status = models.CharField(
        max_length=100,
        default="Pending"
    )

    tracking_data = models.JSONField(
        blank=True,
        null=True
    )

    refund_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        default=0
    )

    refund_status = models.CharField(
        max_length=30,
        default="PENDING"
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return self.return_number    
    
    
from django.db import models

from .models import ShipOrder
from accounts.models import User


class PackingVideo(models.Model):

    order = models.ForeignKey(
        ShipOrder,
        on_delete=models.CASCADE,
        related_name="packing_videos"
    )

    uploaded_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="packing_videos"
    )

    s3_video = models.URLField(
        max_length=1000
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"{self.order.order_number} - Packing Video"    
    
    



