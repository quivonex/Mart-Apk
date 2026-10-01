from rest_framework import serializers
from .models import Company, CompanyImage
from django.conf import settings




class CompanyImageSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = CompanyImage
        fields = ["id", "image_s3_key", "url"]

    def get_url(self, obj):
        if obj.image_s3_key:
            return f"https://{settings.AWS_S3_CUSTOM_DOMAIN}/{obj.image_s3_key}"
        return None


class CompanySerializer(serializers.ModelSerializer):
    logo = serializers.SerializerMethodField()
    images = CompanyImageSerializer(many=True, read_only=True)

    class Meta:
        model = Company
        fields = "__all__"
        read_only_fields = ["is_active"]

    def validate(self, attrs):
        unique_fields = {
            "name": "Company name",
            "email": "Email",
            "gst_number": "GST number",
            "registration_no": "Registration number",
            "company_pan_no": "PAN number",
        }

        for field, label in unique_fields.items():
            value = attrs.get(field)

            # Skip if field not sent or blank
            if value in [None, ""]:
                continue

            queryset = Company.objects.filter(**{field: value})

            # Ignore current company during update
            if self.instance:
                queryset = queryset.exclude(id=self.instance.id)

            if queryset.exists():
                raise serializers.ValidationError({
                    field: f"{label} already exists."
                })

        return attrs

    def get_logo(self, obj):
        if obj.logo_s3_key:
            return f"https://{settings.AWS_S3_CUSTOM_DOMAIN}/{obj.logo_s3_key}"
        return None
    
class CompanynameSerializer(serializers.ModelSerializer):

     class Meta:
        model = Company
        fields = ['id', 'name']


from rest_framework import serializers
from .models import Company

class CompanyListSerializer(serializers.ModelSerializer):

    class Meta:
        model = Company
        fields = ["id","logo_s3_key", "name", "owner_name"]        



from .models import suppliers

class SupplierSerializer(serializers.ModelSerializer):
    class Meta:
        model = suppliers
        fields = '__all__'
     