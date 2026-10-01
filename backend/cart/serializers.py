# from rest_framework import serializers
# from .models import CartItem
# from django.conf import settings


# class CartItemSerializer(serializers.ModelSerializer):

#     user_name = serializers.CharField(source="user.username", read_only=True)
#     product_name = serializers.CharField(source="product.name", read_only=True)
#     product_image = serializers.SerializerMethodField()

#     class Meta:
#         model = CartItem
#         fields = [
#             'id',
#             'user',
#             'user_name',
#             'product',
#             'product_name',
#             'product_image',
#             'quantity',
#             'added_at'
#         ]
#         read_only_fields = ['id', 'user', 'added_at']

#     def get_product_image(self, obj):
#         image = obj.product.images.first()   # first product image
#         if image:
#             return f"https://{settings.AWS_S3_CUSTOM_DOMAIN}/{image.image_s3_key}"
#         return None


from rest_framework import serializers
from .models import CartItem
from product.models import Product


class CartItemSerializer(serializers.ModelSerializer):

    user_name = serializers.CharField(source="user.username", read_only=True)
    product_name = serializers.CharField(source="product.name", read_only=True)
    product_code = serializers.CharField(source="product.product_code", read_only=True)
    COD_available = serializers.BooleanField(source="product.company.COD_available", read_only=True)

    thumbnail = serializers.CharField(source="product.thumbnail_s3_key", read_only=True)

    unit_price = serializers.SerializerMethodField()
    total_price = serializers.SerializerMethodField()

    class Meta:
        model = CartItem
        fields = [
            'id',
            'user',
            'user_name',
            'product',
            'product_name',
            'product_code',
            'COD_available',
            'thumbnail',

            'unit_price',
            'quantity',
            'total_price',
            'added_at'
        ]
        read_only_fields = ['id', 'user', 'added_at']


    def get_unit_price(self, obj):
        return obj.product.final_price if obj.product.final_price else obj.product.price


    def get_total_price(self, obj):
        price = obj.product.final_price if obj.product.final_price else obj.product.price
        return price * obj.quantity