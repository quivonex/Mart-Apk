from rest_framework import serializers # type: ignore
from .models import State,District,Taluka, Village

class StateSerializer(serializers.ModelSerializer):
    class Meta:
        model = State
        fields = [
            'id',
            'state_code',
            'state_name',
            'is_active',
            'created_at',
            'updated_at',
        ]



class DistrictSerializer(serializers.ModelSerializer):
    class Meta:
        model = District
        fields = '__all__'

class TalukaSerializer(serializers.ModelSerializer):
    class Meta:
        model = Taluka
        fields = '__all__'




class VillageSerializer(serializers.ModelSerializer):
    state = serializers.PrimaryKeyRelatedField(queryset=State.objects.all())
    district = serializers.PrimaryKeyRelatedField(queryset=District.objects.all())
    taluka = serializers.PrimaryKeyRelatedField(queryset=Taluka.objects.all())

    class Meta:
        model = Village
        fields = '__all__'