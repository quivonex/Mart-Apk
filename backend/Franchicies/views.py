from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

from .models import  Franchise, FranchisePlan
from .serializers import FranchisePlanSerializer, FranchiseSerializer


class FranchiseCreateAPIView(APIView):

    def post(self, request):
        data = request.data.copy()

        # URL मधून referral code घ्या
        referral_code = request.query_params.get("ref")

        if referral_code:
            data["franchise_referral_code"] = referral_code

        serializer = FranchiseSerializer(data=data)

        if serializer.is_valid():
            serializer.save()
            return Response(
                {
                    "status": "success",
                    "message": "Franchise created successfully",
                    "data": serializer.data
                },
                status=status.HTTP_201_CREATED
            )

        return Response(
            {
                "status": "error",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
        
class FranchiseListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        franchises = Franchise.objects.all().order_by('-id')

        serializer = FranchiseSerializer(
            franchises,
            many=True
        )

        return Response({
            "status": "success",
            "message": "Franchise list fetched successfully",
            "total": franchises.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)  
        
class FranchisePublicListAPIView(APIView):
    def post(self, request):
        franchises = Franchise.objects.filter(is_active=True).order_by('-id')

        serializer = FranchiseSerializer(
            franchises,
            many=True
        )

        return Response({
            "status": "success",
            "message": "Franchise list fetched successfully",
            "total": franchises.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    def post(self, request):
        franchises = Franchise.objects.all().order_by('-id')

        serializer = FranchiseSerializer(
            franchises,
            many=True
        )
    
        return     Response({
            "status": "success",
            "message": "Franchise list fetched successfully",
            "total": franchises.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)        
              
class FranchisePlanCreateAPIView(APIView):

    def post(self, request):
        serializer = FranchisePlanSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()

            return Response({
                "status": True,
                "message": "Franchise Plan created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)        
        
        
        
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated


class FranchisePlanRetrieveAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        plans = FranchisePlan.objects.filter(
            user=request.user
        ).select_related(
            'company'
        ).prefetch_related(
            'items'
        )

        serializer = FranchisePlanSerializer(plans, many=True)

        return Response({
            "status": True,
            "count": plans.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)        
        
        
        
        

from product.models import Product
class CompanyFranchisePlanAPIView(APIView):

    def post(self, request):
        slug = request.data.get("slug")

        if not slug:
            return Response({
                "status": False,
                "message": "Product slug is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        # Get Product
        try:
            product = Product.objects.get(
                slug=slug,
                is_active=True
            )
        except Product.DoesNotExist:
            return Response({
                "status": False,
                "message": "Product not found."
            }, status=status.HTTP_404_NOT_FOUND)

        # Get Franchise Plans
        plans = FranchisePlan.objects.filter(
            product=product,
            is_active=True
        ).select_related(
            "company",
            "product"
        ).prefetch_related(
            "items"
        )

        if not plans.exists():
            return Response({
                "status": False,
                "message": "No franchise plans found.",
                "count": 0,
                "data": []
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = FranchisePlanSerializer(plans, many=True)

        return Response({
            "status": True,
            "message": "Franchise plans fetched successfully.",
            "count": plans.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
                
class GenerateReferralLinkAPIView(APIView):

    def post(self, request):
        referral_code = request.data.get("referral_code")
        product = request.data.get("product")   # Product slug

        if not referral_code:
            return Response(
                {
                    "status": "error",
                    "message": "Referral code is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if not product:
            return Response(
                {
                    "status": "error",
                    "message": "Product slug is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        base_url = "https://qnxmartb2b.com/franchise-apply/"

        referral_link = (
            f"{base_url}?product={product}&ref_code={referral_code}"
        )

        return Response(
            {
                "status": "success",
                "message": "Referral link generated successfully.",
                "data": {
                    "product": product,
                    "referral_code": referral_code,
                    "referral_link": referral_link
                }
            },
            status=status.HTTP_200_OK
        )        