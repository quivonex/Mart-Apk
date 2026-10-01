from rest_framework import serializers # type: ignore
from .models import Enquiry, MarketingPartner
from .models import Uenquiry

class EnquirySerializer(serializers.ModelSerializer):

    class Meta:
        model = Enquiry
        fields = "__all__"



class UenquirySerializer(serializers.ModelSerializer):
    class Meta:
        model = Uenquiry
        fields = '__all__'  


class LatestEnquirySerializer(serializers.ModelSerializer):
    class Meta:
        model = Enquiry
        fields = ['id', 'person_name', 'shop_name', 'company_name']



from rest_framework import serializers # type: ignore
from .models import ProductEnquiry

from product.models import ProductImage, ProductVariant


class ProductImageSerializer(serializers.ModelSerializer):

    class Meta:
        model = ProductImage
        fields = [
            "id",
            "image_s3_key"
        ]


class ProductVariantSerializer(serializers.ModelSerializer):

    final_price = serializers.SerializerMethodField()

    class Meta:
        model = ProductVariant
        fields = [
            "id",
            "attributes",
            "price",
            "final_price",
            "stock_quantity",
            "sku",
            "image_s3_key"
        ]

    def get_final_price(self, obj):
        return obj.get_final_price_with_offer()

class ProductEnquirySerializer(serializers.ModelSerializer):

    product_name = serializers.CharField(
        source="product.name",
        read_only=True
    )
    company_name = serializers.CharField(
        source="product.company.name",
        read_only=True
    )
    product_description = serializers.CharField(
        source="product.description",
        read_only=True
    )

    product_price = serializers.DecimalField(
        source="product.final_price",
        max_digits=10,
        decimal_places=2,
        read_only=True
    )

    # ✅ MAIN PRODUCT IMAGE
    product_image = serializers.CharField(
        source="product.thumbnail_s3_key",
        read_only=True
    )

    # ✅ SELECTED VARIANT ONLY
    variants=serializers.SerializerMethodField()

    class Meta:
        model = ProductEnquiry
        fields = "__all__"

    def get_variants(self, obj):

        variants=obj.product.variants.all()

        return ProductVariantSerializer(variants,many=True).data

    def validate(self, data):

        if (
            data.get("demo_required") == "yes"
            and not data.get("demo_type")
        ):
            raise serializers.ValidationError({
                "demo_type": "Required"
            })

        return data      

from rest_framework import serializers
from .models import BankDetails


class BankDetailsSerializer(serializers.ModelSerializer):

    class Meta:
        model = BankDetails
        fields = "__all__"


from rest_framework import serializers
from .models import MarketingPartner


# class MarketingPartnerSerializer(serializers.ModelSerializer):

#     # 🔹 FRONTEND sends referral code
#     referred_by_code = serializers.CharField(
#         write_only=True,
#         required=False
#     )

#     # 🔹 SHOW referred partner name
#     referred_by_name = serializers.SerializerMethodField()

#     # 🔹 SHOW referred partner referral code
#     referred_by_referral_code = serializers.SerializerMethodField()

#     class Meta:

#         model = MarketingPartner

#         fields = "__all__"

#         read_only_fields = (
#             'user',
#             'status',
#             'otp_verified',
#             'referral_code',
#             'referral_link'
#         )

#     # 🔹 Validate promotion platforms
#     def validate_promotion_platforms(self, value):

#         valid_platforms = [
#             'instagram',
#             'facebook',
#             'youtube',
#             'whatsapp',
#             'offline',
#             'other'
#         ]

#         for platform in value:

#             if platform not in valid_platforms:

#                 raise serializers.ValidationError(
#                     f"{platform} is invalid"
#                 )

#         return value

#     # 🔹 Get referred by name
#     def get_referred_by_name(self, obj):

#         if obj.referred_by:
#             return obj.referred_by.full_name

#         return None

#     # 🔹 Get referred by referral code
#     def get_referred_by_referral_code(self, obj):

#         if obj.referred_by:
#             return obj.referred_by.referral_code

#         return None

#     # 🔹 Remove custom field before create
#     def create(self, validated_data):

#         validated_data.pop(
#             'referred_by_code',
#             None
#         )

#         return super().create(validated_data)

from rest_framework import serializers
from cryptography.fernet import Fernet
from django.conf import settings

from .models import MarketingPartner
from agreement.models import MarketingPartnerAgreement

cipher = Fernet(settings.FIELD_ENCRYPTION_KEY.encode())


def encrypt_value(value):
    if value:
        return cipher.encrypt(value.encode()).decode()
    return None


class MarketingPartnerSerializer(serializers.ModelSerializer):

    referral_code = serializers.SerializerMethodField()
    referral_link = serializers.SerializerMethodField()

    referred_by_code = serializers.CharField(
        write_only=True,
        required=False
    )

    referred_by_name = serializers.SerializerMethodField()
    referred_by_referral_code = serializers.SerializerMethodField()

    class Meta:
        model = MarketingPartner
        fields = "__all__"

        read_only_fields = (
            "user",
            "status",
            "otp_verified",
        )

    def get_referral_code(self, obj):

        is_approved = MarketingPartnerAgreement.objects.filter(
            marketing_partner=obj,
            status="approved"
        ).exists()

        if is_approved:
            return obj.referral_code

        return encrypt_value(obj.referral_code)

    def get_referral_link(self, obj):

        is_approved = MarketingPartnerAgreement.objects.filter(
            marketing_partner=obj,
            status="approved"
        ).exists()

        if is_approved:
            return obj.referral_link

        return encrypt_value(obj.referral_link)
    

    def get_referred_by_name(self, obj):

        if obj.referred_by:
            return obj.referred_by.full_name

        return None

    def get_referred_by_referral_code(self, obj):

        if not obj.referred_by:
            return None

        is_approved = MarketingPartnerAgreement.objects.filter(
            marketing_partner=obj.referred_by,
            status="approved"
        ).exists()

        if is_approved:
            return obj.referred_by.referral_code

        return encrypt_value(obj.referred_by.referral_code)

    def create(self, validated_data):

        validated_data.pop(
            "referred_by_code",
            None
        )

        return super().create(validated_data)
    

from rest_framework import serializers
from .models import ProductEnquiry
from product.models import ProductImage
from .serializers import ProductVariantSerializer,ProductImageSerializer


class CompanyProductEnquirySerializer(serializers.ModelSerializer):

    product_name=serializers.CharField(
        source="product.name",
        read_only=True
    )

    product_image=serializers.CharField(
        source="product.thumbnail_s3_key",
        read_only=True
    )

    variants=serializers.SerializerMethodField()


    class Meta:
        model=ProductEnquiry
        fields="__all__"


    def get_variants(self,obj):

        variants=obj.product.variants.all()

        return ProductVariantSerializer(
            variants,
            many=True
        ).data


    def mask_name(self,v):

        if not v:
            return v

        return v[0]+"*"*(len(v)-2)+v[-1]


    def mask_email(self,v):

        if not v:
            return v

        name,domain=v.split("@")

        return (
            name[:2]
            +"*"*(len(name)-2)
            +"@"
            +domain
        )


    def mask_contact(self,v):

        if not v:
            return v

        return (
            v[:2]
            +"*"*(len(v)-4)
            +v[-2:]
        )


    def to_representation(self,obj):

        data=super().to_representation(obj)

        data["person_name"]=self.mask_name(
            obj.person_name
        )

        data["email"]=self.mask_email(
            obj.email
        )

        data["contact"]=self.mask_contact(
            obj.contact
        )

        return data