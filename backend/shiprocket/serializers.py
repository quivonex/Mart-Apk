from rest_framework import serializers
from .models import Shipment


class ShipmentListSerializer(serializers.ModelSerializer):
    order_number = serializers.CharField(
        source="order.order_number",
        read_only=True
    )

    class Meta:
        model = Shipment
        fields = [
            "id",
            "order",
            "order_number",
            "shiprocket_order_id",
            "shipment_id",
            "awb_code",
            "courier_company",
            "tracking_url",
            "shipping_charge",
            "label_url",
            "pickup_request_id",
            "pickup_status",
            "tracking_data",
            "manifest_url",
            "status",
            "created_at",
            "updated_at",
        ]
        
        
from rest_framework import serializers

from .models import PackingVideo


class PackingVideoSerializer(serializers.ModelSerializer):

    class Meta:
        model = PackingVideo
        fields = [
            "id",
            "order",
            "uploaded_by",
            "s3_video",
        ]

        read_only_fields = [
            "id",
            "uploaded_by",
        ]        