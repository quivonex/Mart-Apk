from rest_framework import serializers
from .models import LoanEnquiry


class LoanEnquirySerializer(serializers.ModelSerializer):

    class Meta:
        model = LoanEnquiry
        fields = "__all__"