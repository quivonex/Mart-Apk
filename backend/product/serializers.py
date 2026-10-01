
from rest_framework import serializers # type: ignore
from .models import Category, Brand, Product, ProductVariant, ProductVideo, SubCategory, Unit
from django.conf import settings # type: ignore
import json

from django.db.models import Q
from datetime import date




import json
from rest_framework import serializers

class FlexibleJSONField(serializers.JSONField):
    def to_internal_value(self, data):
        try:
            # already सही आहे
            if isinstance(data, (list, dict)):
                return data

            if isinstance(data, str):
                data = data.strip()

                # 🔥 multiple decode attempt
                while isinstance(data, str):
                    try:
                        data = json.loads(data)
                    except Exception:
                        break

                if isinstance(data, (list, dict)):
                    return data

            raise serializers.ValidationError("Invalid JSON format")

        except Exception:
            raise serializers.ValidationError("Invalid JSON format")
    



class MaterialCategorySerializer(serializers.ModelSerializer):
    branch_name = serializers.CharField(source="branch.name", read_only=True)
    company_name = serializers.CharField(source="company.name", read_only=True)
    
    class Meta:
        model = Category
        fields = '__all__'

class CategorynameSerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = ['id', 'name']


class SubCategorySerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)

    class Meta:
        model = SubCategory
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at']        


from rest_framework import serializers
from .models import Brand


class BrandSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source="user.username", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    subcategory_name = serializers.CharField(source="subcategory.name", read_only=True)

    class Meta:
        model = Brand
        fields = [
            "id",
            "name",
            "description",
            "is_active",
            "created_at",
            "user_name",
            "category_id",
            "subcategory_id",
            "category_name",
            "subcategory_name",
        ]



from .models import Product, ProductImage

class ProductImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ProductImage
        fields = ['id', 'image_s3_key', 'created_at']



class UnitSerializer(serializers.ModelSerializer):
    class Meta:
        model = Unit
        fields = '__all__'            

class ProductVideoSerializer(serializers.ModelSerializer):

    class Meta:
        model = ProductVideo
        fields = '__all__'

class ProductVariantSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()  # ✅ add method field
    final_price = serializers.SerializerMethodField()   # 🔥 ADD

    class Meta:
        model = ProductVariant
        fields = ['id', 'attributes', 'price', 'final_price', 'stock_quantity', 'sku', 'image_index', 'image']  # image_index सोबत image URL

    def get_image(self, obj):
        product_images = list(obj.product.images.all())
        idx = obj.image_index or 0
        if 0 <= idx < len(product_images):
            return product_images[idx].image_s3_key
        return None
    
    # 🔥 ADD THIS
    def get_final_price(self, obj):
        return obj.get_final_price_with_offer()

import json
from rest_framework import serializers
from datetime import date

class ProductSerializer(serializers.ModelSerializer):
    weight = serializers.CharField(required=True)
    length = serializers.CharField(required=True)
    width = serializers.CharField(required=True)
    height = serializers.CharField(required=True)
    images = serializers.SerializerMethodField()  # ❗ override
    
     # 🔥 ADD THESE TWO LINES
    final_price = serializers.SerializerMethodField()   # 🔥 override
    applied_offer = serializers.SerializerMethodField()
    # is_franchise_available = serializers.SerializerMethodField()
    videos = ProductVideoSerializer(many=True, read_only=True)
    variants = ProductVariantSerializer(many=True, read_only=True)

    company_name = serializers.CharField(source="company.name", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    subcategory_name = serializers.CharField(source="subcategory.name", read_only=True)
    brand_name = serializers.CharField(source="brand.name", read_only=True)
    unit_name = serializers.CharField(source="unit.name", read_only=True)
    
    branch_name = serializers.CharField(source="branch.name", read_only=True)

    class Meta:
        model = Product
        fields = '__all__'
    def get_is_franchise_available(self, obj):
        if obj.company:
            return obj.company.is_franchise_available
        return False
    def get_images(self, obj):
        # ❗ फक्त product images (variant images exclude)
        images = obj.images.exclude(image_s3_key__contains="variant_images")
        return ProductImageSerializer(images, many=True).data
    
    # ✅ ALWAYS RETURN FINAL CALCULATED PRICE
    def get_final_price(self, obj):
        return obj.get_final_price_with_offer()

    # ✅ OFFER DETAILS
    def get_applied_offer(self, obj):
        today = date.today()
    
        offer = obj.offers.filter(
            is_active=True
        ).filter(
            Q(start_date__lte=today) | Q(start_date__isnull=True),
            Q(end_date__gte=today) | Q(end_date__isnull=True)
        ).order_by('-id').first()

        if not offer:
            return None

        return {
            "id": offer.id,
            "title": offer.title,
            "type": offer.offer_type,
            "value": offer.discount_value
        }
    # def get_applied_offer(self, obj):
    #     offer = obj.offers.first()

    #     if not offer:
    #         return None   # ✅ SAFE

    #     return {
    #         "id": offer.id,
    #         "title": offer.title
    #     }
    #########

    def create(self, validated_data):
        variants_data = validated_data.pop('variants', None)
        product = Product.objects.create(**validated_data)

        if variants_data:
            import json
            if isinstance(variants_data, str):
                try:
                    variants_data = json.loads(variants_data)
                except Exception:
                    variants_data = []

            for idx, variant in enumerate(variants_data):
                # ProductVariant create
                ProductVariant.objects.create(
                    product=product,
                    attributes=variant.get('attributes', {}),
                    price=variant.get('price', 0),
                    stock_quantity=variant.get('stock_quantity', 0) or variant.get('stock', 0),
                    sku=variant.get('sku', ''),
                    image_index=variant.get('image_index', 0)
                )

        return product


class LatestProductSerializer(serializers.ModelSerializer):

    company_name = serializers.CharField(source="company.name", read_only=True)
    category_name = serializers.CharField(source="category.name", read_only=True)
    # is_franchise_available = serializers.SerializerMethodField()
    brand_name = serializers.CharField(source="brand.name", read_only=True)

    thumbnail = serializers.CharField(source="thumbnail_s3_key")

    class Meta:
        model = Product
        fields = [
            "id",
            "thumbnail",
            "name",
            "slug",
            "description",
            "company_name",
            "category_name",
            "is_franchise_available",
            "brand_name"
        ]
        
    def get_is_franchise_available(self, obj):
        if obj.company:
            return obj.company.is_franchise_available
        return False    


# new added serializer for search history
from .models import SearchHistory


class SearchHistorySerializer(serializers.ModelSerializer):

    class Meta:
        model = SearchHistory
        fields = ['id', 'search_text', 'searched_at']


class ProductUpdateRequestSerializer(serializers.Serializer):

    product_id = serializers.IntegerField()

    name = serializers.CharField(required=False)
    description = serializers.CharField(required=False)

    price = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)
    discount_value = serializers.DecimalField(max_digits=10, decimal_places=2, required=False)

    stock_quantity = serializers.IntegerField(required=False)

    specifications = serializers.JSONField(required=False)
    variants = serializers.JSONField(required=False)
    variant_attributes = serializers.JSONField(required=False)

    # FK fields
    company = serializers.IntegerField(required=False)
    category = serializers.IntegerField(required=False)
    subcategory = serializers.IntegerField(required=False)
    brand = serializers.IntegerField(required=False)
    unit = serializers.IntegerField(required=False)
    branch = serializers.IntegerField(required=False)


class ProductApproveSerializer(serializers.ModelSerializer):

    class Meta:
        model = Product
        fields = "__all__"
        extra_kwargs = {
            "name": {"required": False},
            "description": {"required": False},
            "price": {"required": False},
            "discount_value": {"required": False},
            "stock_quantity": {"required": False},
            "category": {"required": False},
            "subcategory": {"required": False},
            "brand": {"required": False},
            "unit": {"required": False},
            "company": {"required": False},
            "branch": {"required": False},
        }