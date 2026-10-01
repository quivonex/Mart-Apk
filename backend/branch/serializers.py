from rest_framework import serializers
from .models import Branch

class BranchSerializer(serializers.ModelSerializer):
    company_name = serializers.CharField(source="company.name", read_only=True)
    class Meta:
        model = Branch
        fields = '__all__'