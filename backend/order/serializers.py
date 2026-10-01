from rest_framework import serializers

from state.models import Village
from .models import Order, OrderItem
from .models import Address


class OrderItemSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source='product.name', read_only=True)
    company_id = serializers.IntegerField(source='product.company.id', read_only=True)
    company_name = serializers.CharField(source='product.company.name', read_only=True)

    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product',
            'product_name',
            'company_id',      # 👈 ADD
            'company_name',    # 👈 ADD
            'quantity',
            'price'
        ]
        
class AddressSerializer(serializers.ModelSerializer):

    class Meta:
        model = Address
        fields = '__all__'
        read_only_fields = ['user']

    def create(self, validated_data):
        request = self.context.get('request')

        if not request or not request.user or request.user.is_anonymous:
            raise serializers.ValidationError("User authentication required")

        validated_data['user'] = request.user
        return Address.objects.create(**validated_data)
        
                
class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    user_name = serializers.CharField(source='user.username', read_only=True)
    address = AddressSerializer(read_only=True)
    class Meta:
        model = Order
        fields = [
            'id',
            'order_id',
            'user',
            'user_name',
            'full_name',
            'address',
            'total_amount',
            'payment_method',
            'payment_status',
            'status',
            'created_at',
            'items'
        ]
        
        
        
