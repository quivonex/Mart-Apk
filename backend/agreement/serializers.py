


import uuid

from rest_framework import serializers

from agreement.models import CompanyAgreement, AgreementProduct
from product.models import Product
from agreement.models import MarketingPartnerAgreement


class AgreementProductCreateSerializer(serializers.Serializer):

    product = serializers.IntegerField()

    profit_percentage = serializers.DecimalField(
        max_digits=5,
        decimal_places=2
    )

    def validate_profit_percentage(self, value):

        if value < 0:
            raise serializers.ValidationError(
                "Profit percentage cannot be negative."
            )

        if value > 100:
            raise serializers.ValidationError(
                "Profit percentage cannot exceed 100."
            )

        return value


class CompanyAgreementCreateSerializer(
    serializers.ModelSerializer
):

    agreement_products = AgreementProductCreateSerializer(
        many=True,
        required=True
    )

    class Meta:

        model = CompanyAgreement

        fields = [
            'agreement_number',
            'company',
            'agreement_role',
            'apply_on_all_products',
            'agreement_start_date',
            'agreement_end_date',
            'company_owner_name',
            'company_address',

            'seller_adhar_number',
            'owner_adhar_number',

            'seller_pan_number',
            'owner_pan_number',

            'additional_points',
            'qnx_mart_representative',

            'qnx_mart_sign_s3_key',
            'company_sign_s3_key',
            'qnx_mart_picture_s3_key',
            'company_picture_s3_key',
            'uploaded_agreement_pdf_s3_key',

            'remarks',

            'agreement_products'
        ]

        extra_kwargs = {
            'agreement_number': {
                'read_only': True
            }
        }

    def validate(self, attrs):

        company = attrs.get('company')

        agreement_products = attrs.get(
            'agreement_products',
            []
        )

        if not agreement_products:

            raise serializers.ValidationError({
                'agreement_products':
                    'At least one product is required.'
            })

        product_ids = [
            item['product']
            for item in agreement_products
        ]

        if len(product_ids) != len(set(product_ids)):

            raise serializers.ValidationError({
                'agreement_products':
                    'Same product cannot be added multiple times.'
            })

        company_product_ids = set(
            Product.objects.filter(
                company=company,
                id__in=product_ids
            ).values_list(
                'id',
                flat=True
            )
        )

        invalid_products = [
            product_id
            for product_id in product_ids
            if product_id not in company_product_ids
        ]

        if invalid_products:

            raise serializers.ValidationError({
                'agreement_products':
                    f'Products {invalid_products} do not belong '
                    f'to the selected company.'
            })

        invalid_status_products = Product.objects.filter(
            id__in=product_ids,
            company=company
        ).exclude(
            is_active=True,
            status='approved'
        )

        if invalid_status_products.exists():

            ids = list(
                invalid_status_products.values_list(
                    'id',
                    flat=True
                )
            )

            raise serializers.ValidationError({
                'agreement_products':
                    f'Products {ids} are not active and approved.'
            })

        return attrs

    # -----------------------------------------
    # Generate Agreement Number
    # -----------------------------------------
    def generate_agreement_number(self):

        while True:

            agreement_number = (
                f"AGR-{uuid.uuid4().hex[:10].upper()}"
            )

            if not CompanyAgreement.objects.filter(
                agreement_number=agreement_number
            ).exists():

                return agreement_number

    # -----------------------------------------
    # Create
    # -----------------------------------------
    def create(self, validated_data):

        agreement_products = validated_data.pop(
            'agreement_products',
            []
        )

        # Auto generate agreement number
        agreement_number = (
            self.generate_agreement_number()
        )

        agreement = CompanyAgreement.objects.create(
            agreement_number=agreement_number,
            **validated_data
        )

        AgreementProduct.objects.bulk_create([
            AgreementProduct(
                agreement=agreement,
                product_id=item['product'],
                profit_percentage=item.get(
                    'profit_percentage'
                )
            )
            for item in agreement_products
        ])

        return agreement
    
    
    
    
import uuid

from rest_framework import serializers

from .models import MarketingPartnerAgreement


class MarketingPartnerAgreementCreateSerializer(
    serializers.ModelSerializer
):

    class Meta:

        model = MarketingPartnerAgreement

        fields = [
            'agreement_number',
            'marketing_partner',
            'agreement_role',
            'agreement_start_date',
            'agreement_end_date',

            'marketing_partner_name',
            'marketing_partner_address',
            'adhar_number',
            'pan_number',
            'company_commission_percentage',
            'profit_share_percentage',
            'selling_commission_percentage',

            'additional_points',
            'qnx_mart_representative',

            'qnx_mart_sign_s3_key',
            'marketing_partner_sign_s3_key',

            'qnx_mart_picture_s3_key',
            'marketing_partner_picture_s3_key',

            'uploaded_agreement_pdf_s3_key',

            'remarks'
        ]

        extra_kwargs = {
            'agreement_number': {
                'read_only': True
            }
        }

    # -----------------------------------------
    # Company Commission
    # -----------------------------------------
    def validate_company_commission_percentage(self, value):

        if value < 0:
            raise serializers.ValidationError(
                "Company commission percentage cannot be negative."
            )

        if value > 100:
            raise serializers.ValidationError(
                "Company commission percentage cannot exceed 100."
            )

        return value

    # -----------------------------------------
    # Profit Share
    # -----------------------------------------
    def validate_profit_share_percentage(self, value):

        if value < 0:
            raise serializers.ValidationError(
                "Profit share percentage cannot be negative."
            )

        if value > 100:
            raise serializers.ValidationError(
                "Profit share percentage cannot exceed 100."
            )

        return value

    # -----------------------------------------
    # Selling Commission
    # -----------------------------------------
    def validate_selling_commission_percentage(self, value):

        if value < 0:
            raise serializers.ValidationError(
                "Selling commission percentage cannot be negative."
            )

        if value > 100:
            raise serializers.ValidationError(
                "Selling commission percentage cannot exceed 100."
            )

        return value

    # -----------------------------------------
    # Generate Agreement Number
    # -----------------------------------------
    def generate_agreement_number(self):

        while True:

            agreement_number = (
                f"AGR-{uuid.uuid4().hex[:10].upper()}"
            )

            if not MarketingPartnerAgreement.objects.filter(
                agreement_number=agreement_number
            ).exists():

                return agreement_number

    # -----------------------------------------
    # Create
    # -----------------------------------------
    def create(self, validated_data):

        agreement_number = (
            self.generate_agreement_number()
        )

        agreement = MarketingPartnerAgreement.objects.create(
            agreement_number=agreement_number,
            **validated_data
        )

        return agreement