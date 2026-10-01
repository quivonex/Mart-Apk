from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import SellerCreateSerializer
from .models import Seller
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication  

class SellerCreateView(APIView):
    authentication_classes = [JWTAuthentication]   # 👈 token auth
    permission_classes = [IsAuthenticated]         # 👈 login required

    def post(self, request):
        serializer = SellerCreateSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response({
                "status": "success",
                "message": "Seller information submitted successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": "error",
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    


class SellerListView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        sellers = Seller.objects.filter(user=request.user)  # ✅ FIX

        serializer = SellerCreateSerializer(sellers, many=True)

        return Response({
            "status": "success",
            "data": serializer.data
        })
    

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from .models import Seller
from .serializers import SellerCreateSerializer

class SellerUpdateView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        seller_id = request.data.get('id')  # 👈 ID body मधून

        if not seller_id:
            return Response({
                "status": "error",
                "message": "Seller ID is required"
            }, status=400)

        try:
            # 👇 फक्त login user चा seller मिळेल
            seller = Seller.objects.get(id=seller_id, user=request.user)
        except Seller.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Seller not found"
            }, status=404)

        serializer = SellerCreateSerializer(seller, data=request.data, partial=True)

        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": "success",
                "message": "Seller updated successfully",
                "data": serializer.data
            })

        return Response({
            "status": "error",
            "errors": serializer.errors
        }, status=400)    