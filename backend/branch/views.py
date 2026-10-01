from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework import status


from .models import Branch
from .serializers import BranchSerializer
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from product.models import Category
from product.serializers import MaterialCategorySerializer

from django.shortcuts import get_object_or_404

class BranchCreateView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = BranchSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Branch created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CompanyBranchesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company_id = request.data.get("company_id")

        if not company_id:
            return Response({
                "status": False,
                "message": "company_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        branches = Branch.objects.filter(company_id=company_id)

        serializer = BranchSerializer(branches, many=True)

        return Response({
            "status": True,
            "message": "Branches fetched successfully",
            "data": serializer.data
        })
    
class BranchCategoriesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        branch_id = request.data.get("branch_id")

        if not branch_id:
            return Response({
                "status": False,
                "message": "branch_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        categories = Category.objects.filter(branch_id=branch_id, is_active=True)

        serializer = MaterialCategorySerializer(categories, many=True)

        return Response({
            "status": True,
            "message": "Categories fetched successfully",
            "data": serializer.data
        })   



class CompanyBranchListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "No company found"
            }, status=400)

        # 🔥 Fetch branches
        branches = Branch.objects.filter(company=company)

        # 🔥 Serialize full data
        serializer = BranchSerializer(branches, many=True)

        return Response({
            "status": True,
            "message": "Company branches fetched successfully",
            "count": branches.count(),
            "data": serializer.data
        })


class BranchUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        branch_id = request.data.get("id")

        if not branch_id:
            return Response({
                "status": False,
                "message": "Branch ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔥 Get user's company
        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "No company found"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔐 Restrict to company branch
        branch = get_object_or_404(
            Branch,
            id=branch_id,
            company=company
        )

        # 🔥 Partial update
        serializer = BranchSerializer(
            branch,
            data=request.data,
            partial=True
        )

        if serializer.is_valid():
            serializer.save()   # company remains unchanged

            return Response({
                "status": True,
                "message": "Branch updated successfully",
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class BranchSoftDeleteAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        branch_id = request.data.get("id")

        if not branch_id:
            return Response({
                "status": False,
                "message": "Branch ID is required"
            }, status=400)

        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "No company found"
            }, status=400)

        branch = get_object_or_404(
            Branch,
            id=branch_id,
            company=company
        )

        if not branch.is_active:
            return Response({
                "status": False,
                "message": "Branch already deleted"
            }, status=400)

        # 🔥 Soft delete
        branch.is_active = False
        branch.save()

        return Response({
            "status": True,
            "message": "Branch soft deleted successfully"
        })


class BranchRestoreAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        branch_id = request.data.get("id")

        if not branch_id:
            return Response({
                "status": False,
                "message": "Branch ID is required"
            }, status=400)

        company = request.user.companies.first()

        if not company:
            return Response({
                "status": False,
                "message": "No company found"
            }, status=400)

        branch = get_object_or_404(
            Branch,
            id=branch_id,
            company=company
        )

        if branch.is_active:
            return Response({
                "status": False,
                "message": "Branch is already active"
            }, status=400)

        # 🔥 Restore
        branch.is_active = True
        branch.save()

        return Response({
            "status": True,
            "message": "Branch restored successfully"
        })