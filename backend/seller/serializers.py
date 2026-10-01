from rest_framework import serializers
from .models import Seller

class SellerCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Seller
        fields = '__all__'

    def validate_pincode(self, value):
        if len(value) != 6 or not value.isdigit():
            raise serializers.ValidationError("Invalid pincode")
        return value

    def validate_mobile(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("Mobile must be numeric")
        return value