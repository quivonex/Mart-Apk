from rest_framework import serializers # type: ignore
from django.contrib.auth.hashers import make_password, check_password # type: ignore
from .models import UserAdmin

from rest_framework import serializers
from .models import UserAdmin


class UserAdminSerializer(serializers.ModelSerializer):

    class Meta:
        model = UserAdmin
        fields = [
            "id",
            "username",
            "password",
            "name",
            "email",
            "phone_number",
            "role"
        ]
        extra_kwargs = {
            "password": {"write_only": True}
        }

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = UserAdmin(**validated_data)
        user.set_password(password)
        user.save()
        return user

from .models import admin_Role

class RoleSerializer(serializers.ModelSerializer):

    class Meta:
        model = admin_Role
        fields = "__all__"
        
        
        
from rest_framework import serializers
from .models import CustomerSubscriptionPlan


class CustomerSubscriptionPlanSerializer(serializers.ModelSerializer):

    class Meta:
        model = CustomerSubscriptionPlan
        fields = [
            "id",
            "name",
            "price",
            "enquiry_limit",
            "duration_days",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "created_at",
            "updated_at",
        ]

    def validate_name(self, value):
        if not value.strip():
            raise serializers.ValidationError(
                "Plan name is required."
            )
        return value

    def validate_price(self, value):
        if value < 0:
            raise serializers.ValidationError(
                "Price cannot be negative."
            )
        return value

    def validate_duration_days(self, value):
        if value < 1:
            raise serializers.ValidationError(
                "Duration must be at least 1 day."
            )
        return value        