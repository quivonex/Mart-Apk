from rest_framework import serializers
from .models import User
from django.contrib.auth.hashers import make_password

class UserRegisterSerializer(serializers.ModelSerializer):

    class Meta:
        model = User
        fields = ['username','email','password','name','phone_number', 'role']

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Email already registered")
        return value

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        user = User.objects.create(**validated_data)
        user.is_email_verified = True
        user.save()
        return user
    


# from rest_framework import serializers

# class UserListSerializer(serializers.ModelSerializer):
#     role = serializers.SerializerMethodField()

#     class Meta:
#         model = User
#         fields = [
#             'id',
#             'username',
#             'name',
#             'email',
#             'phone_number',
#             'is_active',
#             'role'
#         ]

#     def get_role(self, obj):
#         return obj.role.role_name if obj.role else None    
    
    
from rest_framework import serializers
from .models import User
from company.models import Company


class UserCompanySerializer(serializers.ModelSerializer):
    class Meta:
        model = Company
        fields = [
            'id',
            'name',
            'email',
            'phone_number',
            'is_active'
        ]


class UserListSerializer(serializers.ModelSerializer):
    role = serializers.SerializerMethodField()
    companies = UserCompanySerializer(many=True, read_only=True)

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'name',
            'email',
            'phone_number',
            'is_active',
            'role',
            'companies'
        ]

    def get_role(self, obj):
        return obj.role.role_name if obj.role else None    
    
    
class UserProfileSerializer(serializers.ModelSerializer):
        
        class Meta:
            model = User
            fields = [
                'id',
                'username',
                'name',
                'email',
                'phone_number',
            ]



# serializers.py

from rest_framework import serializers
from .models import InstagramReel


class InstagramReelSerializer(serializers.ModelSerializer):

    class Meta:
        model = InstagramReel
        fields = [
            "id",
            "reel_link",
            "title",
            "is_active",
            "created_at"
        ]

        read_only_fields = [
            "id",
            "created_at"
        ]