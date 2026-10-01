from rest_framework import serializers

from company.models import Company
from product.models import Product
from .models import Franchise, FranchisePlan, FranchisePlanItem


class FranchiseSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source='company.name', read_only=True)

    class Meta:
        model = Franchise
        fields = "__all__"
        
class CompanyDetailsSerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = [
            'id',
            'name',
            'owner_name',
            'phone_number',
            'email',
            'address',
            'logo_s3_key',
            'is_franchise_available'
        ]

class FranchisePlanProductSerializer(serializers.ModelSerializer):
    class Meta:
        model = FranchisePlanItem
        fields = ['item_name', 'quantity', 'unit']

from rest_framework import serializers
from .models import FranchisePlan, FranchisePlanItem


class FranchisePlanItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = FranchisePlanItem
        fields = [
            "id",
            "item_name",
            "quantity",
            "unit",
        ]
        
        
from rest_framework import serializers
from .models import FranchisePlan, FranchisePlanItem
from product.models import Product


class FranchisePlanSerializer(serializers.ModelSerializer):
    company_id = serializers.IntegerField(
        source="company.id",
        read_only=True
    )

    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all()
    )

    plan_products = FranchisePlanItemSerializer(
        source="items",
        many=True
    )
    company = serializers.PrimaryKeyRelatedField(
    queryset=Company.objects.all(),
    write_only=True
    )

    class Meta:
        model = FranchisePlan
        fields = [
            "id",
            "company_id",
            "user",
            "product",
            "plan_name",
            "amount",
            "description",
            "plan_products",
            "company",
        ]

    def create(self, validated_data):
        items_data = validated_data.pop("items", [])

        franchise_plan = FranchisePlan.objects.create(**validated_data)

        for item in items_data:
            FranchisePlanItem.objects.create(
                franchise_plan=franchise_plan,
                **item
            )

        return franchise_plan