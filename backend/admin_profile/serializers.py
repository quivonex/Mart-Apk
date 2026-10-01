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