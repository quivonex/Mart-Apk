from rest_framework import serializers # type: ignore
from .models import Offer
from product.models import Product

class OfferSerializer(serializers.ModelSerializer):
    product_details = serializers.SerializerMethodField()
    branch_names = serializers.SerializerMethodField()

    class Meta:
        model = Offer
        fields = "__all__"

    def get_product_details(self, obj):
        data = []
        for product in obj.products.all():
            data.append({
                "product_name": product.name,
                "company": product.company.name if product.company else None
            })
        return data

    def get_branch_names(self, obj):
        branches = []
        for product in obj.products.all():
            if product.branch:
                branches.append(product.branch.name)
        return list(set(branches)) if branches else []