from httpx import request
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework import status
from .models import Offer
from .serializers import OfferSerializer
from product.models import Product
from decimal import Decimal
from product.models import Product

# CREATE OFFER
class CreateOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = OfferSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Offer created successfully",
                "data": serializer.data
            }, status=201)
        return Response(serializer.errors, status=400)


# VIEW ALL OFFERS
class OfferListView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offers = Offer.objects.all()
        serializer = OfferSerializer(offers, many=True)
        return Response({
            "message": "Offers fetched successfully",
            "data": serializer.data
        })

class OfferListallView(APIView):
 
    def post(self, request):
        offers = Offer.objects.all()
        serializer = OfferSerializer(offers, many=True)
        return Response({
            "message": "Offers fetched successfully",
            "data": serializer.data
        })


# VIEW SINGLE OFFER
class OfferDetailView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        serializer = OfferSerializer(offer)
        return Response({
            "message": "Offer fetched successfully",
            "data": serializer.data
        })


# UPDATE OFFER
class UpdateOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        serializer = OfferSerializer(offer, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response({
                "message": "Offer updated successfully",
                "data": serializer.data
            })
        return Response(serializer.errors, status=400)


# HARD DELETE (Optional - admin only later)
class DeleteOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        offer.delete()
        return Response({
            "message": "Offer deleted successfully"
        })


# SOFT DELETE
class SoftDeleteOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({"message": "ID is required"}, status=400)
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        if not offer.is_active:
            return Response({"message": "Offer already deleted"}, status=400)
        offer.is_active = False
        offer.save()
        return Response({
            "message": "Offer soft deleted successfully"
        })


# RESTORE
class RestoreOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({"message": "ID is required"}, status=400)
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        if offer.is_active:
            return Response({"message": "Offer is already active"}, status=400)
        offer.is_active = True
        offer.save()
        return Response({
            "message": "Offer restored successfully"
        })


# APPLY OFFER TO PRODUCTS
class ApplyOfferToProductAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("offer_id")
        product_ids = request.data.get("product_ids", [])
        branch_ids = request.data.get("branch_ids", []) # 🔥 optional
        branch_ids = list(map(int, branch_ids)) if branch_ids else [] # 🔥 optional
        # ✅ Validate
        if not offer_id:
            return Response({"message": "offer_id required"}, status=400)
        if not product_ids:
            return Response({"message": "product_ids required"}, status=400)
        # ✅ Get company of logged-in user
        company = request.user.companies.first()
        if not company:
            return Response({"message": "No company found"}, status=400)
        # ✅ Get offer (company restricted)
        offer = Offer.objects.filter(
            id=offer_id,
            company=company,
            is_active=True
        ).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        # ✅ Get products (only company products)
        products = Product.objects.filter(
            id__in=product_ids,
            company=company
        )
        if not products.exists():
            return Response({"message": "No valid products found"}, status=404)
        # 🔥 Save branches in offer
        if branch_ids:
            offer.branch.set(branch_ids)
        else:
            offer.branch.clear()  # 👉 means ALL branches
        # 🔥 Apply offer (ONLY ONE OFFER PER PRODUCT)
        updated_products = []
        # convert branch_ids to int (IMPORTANT)
        branch_ids = request.data.get("branch_ids", [])
        branch_ids = list(map(int, branch_ids)) if branch_ids else []
        for product in products:
            # ✅ Updated branch logic (GLOBAL support)
            if branch_ids:
                if product.branch_id is not None and product.branch_id not in branch_ids:
                    continue
            product.offers.clear()
            product.offers.add(offer)
            updated_products.append(product.id)
        return Response({
            "message": "Offer applied successfully",
            "offer_id": offer.id,
            "products_updated": updated_products
        }, status=status.HTTP_200_OK)


# REMOVE OFFER FROM PRODUCTS
class RemoveOfferFromProductAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("offer_id")
        product_ids = request.data.get("product_ids", [])
        offer = Offer.objects.filter(id=offer_id).first()
        if not offer:
            return Response({"message": "Offer not found"}, status=404)
        products = Product.objects.filter(id__in=product_ids)
        offer.products.remove(*products)
        return Response({
            "message": "Offer removed from products"
        })


# SOFT DELETE COMPANY OFFER
class CompanySoftDeleteOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({
                "message": "Offer ID is required"
            }, status=400)
        # 🔥 Get logged-in company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔐 Company-restricted query
        offer = Offer.objects.filter(
            id=offer_id,
            company=company
        ).first()
        if not offer:
            return Response({
                "message": "Offer not found for this company"
            }, status=404)
        if not offer.is_active:
            return Response({
                "message": "Offer already soft deleted"
            }, status=400)
        # 🔥 Soft delete
        offer.is_active = False
        offer.save()
        return Response({
            "message": "Offer soft deleted successfully"
        }, status=200)





# Create Company Offer
class CreateCompanyOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # 🔥 Get company of logged-in user
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found for this user"
            }, status=400)
        serializer = OfferSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(company=company)   # 🔥 attach company
            return Response({
                "message": "Offer created successfully",
                "data": serializer.data
            }, status=201)
        return Response(serializer.errors, status=400)


# List Company Offers
class CompanyOfferListView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # 🔥 Get company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔥 Filter offers by company
        offers = Offer.objects.filter(company=company)
        serializer = OfferSerializer(offers, many=True)
        return Response({
            "message": "Company offers fetched successfully",
            "count": offers.count(),
            "data": serializer.data
        })


# SINGLE COMPANY OFFER DETAIL
class CompanyOfferDetailView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({
                "message": "Offer ID is required"
            }, status=400)
        # 🔥 Get logged-in user's company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔥 Filter by BOTH id + company (IMPORTANT 🔐)
        offer = Offer.objects.filter(
            id=offer_id,
            company=company
        ).first()
        if not offer:
            return Response({
                "message": "Offer not found for this company"
            }, status=404)
        serializer = OfferSerializer(offer)
        return Response({
            "message": "Offer fetched successfully",
            "data": serializer.data
        }, status=200)


# UPDATE COMPANY OFFER
class CompanyOfferUpdateView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({
                "message": "Offer ID is required"
            }, status=400)
        # 🔥 Get logged-in user's company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔥 Get offer ONLY from this company
        offer = Offer.objects.filter(
            id=offer_id,
            company=company
        ).first()
        if not offer:
            return Response({
                "message": "Offer not found for this company"
            }, status=404)
        # 🔥 Partial update (important)
        serializer = OfferSerializer(
            offer,
            data=request.data,
            partial=True
        )
        if serializer.is_valid():
            serializer.save()   # company stays same
            return Response({
                "message": "Offer updated successfully",
                "data": serializer.data
            }, status=200)
        return Response(serializer.errors, status=400)


# RESTORE COMPANY OFFER
class CompanyRestoreOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({
                "message": "Offer ID is required"
            }, status=400)
        # 🔥 Get logged-in company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔐 Company-restricted query
        offer = Offer.objects.filter(
            id=offer_id,
            company=company
        ).first()
        if not offer:
            return Response({
                "message": "Offer not found for this company"
            }, status=404)
        if offer.is_active:
            return Response({
                "message": "Offer is already active"
            }, status=400)
        # 🔥 Restore
        offer.is_active = True
        offer.save()
        return Response({
            "message": "Offer restored successfully",
            "data": {
                "id": offer.id,
                "title": offer.title,
                "is_active": offer.is_active
            }
        }, status=200)


# HARD DELETE COMPANY OFFER
class CompanyHardDeleteOfferView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        offer_id = request.data.get("id")
        if not offer_id:
            return Response({
                "message": "Offer ID is required"
            }, status=400)
        # 🔥 Get logged-in company
        company = request.user.companies.first()
        if not company:
            return Response({
                "message": "No company found"
            }, status=400)
        # 🔐 Company restriction
        offer = Offer.objects.filter(
            id=offer_id,
            company=company
        ).first()
        if not offer:
            return Response({
                "message": "Offer not found for this company"
            }, status=404)
        # 🔥 Hard delete
        offer.delete()
        return Response({
            "message": "Offer permanently deleted"
        }, status=200)




 
class OfferAutoFilterAPIView(APIView):
 
    def post(self, request):
 
        # ✅ ONLY APPROVED PRODUCTS
        products = Product.objects.filter(
            is_active=True,
            status='approved'
        )
        # 🔥 RANGES
        PERCENT_RANGES = [(70, 100), (50, 70), (30, 50), (0, 30)]
        FLAT_RANGES = [(0, 200), (200, 500), (500, 1000), (1000, 5000)]
        # 🔥 RANGE CHECK FUNCTION
        def in_range(value, min_v, max_v, is_last):
            if is_last:
                return min_v <= value <= max_v
            return min_v <= value < max_v
        product_percent_filters = []
        product_flat_filters = []
        offer_percent_filters = []
        offer_flat_filters = []
        # 🟢 PRODUCT PERCENT FILTER
        for i, (min_p, max_p) in enumerate(PERCENT_RANGES):
            product_ids = []
            for product in products:
                # ❌ skip if offer exists
                if product.offers.filter(is_active=True).exists():
                    continue
                # ✅ ONLY percent type
                if product.discount_type != "percent":
                    continue
                percent = product.discount_value or 0
                if in_range(percent, min_p, max_p, i == len(PERCENT_RANGES) - 1):
                    product_ids.append(product.id)
            product_percent_filters.append({
                "label": f"{min_p}% - {max_p}% Off",
                "min": min_p,
                "max": max_p,
                "product_count": len(product_ids),
                "product_ids": product_ids
            })
        # 🟢 PRODUCT FLAT FILTER
        for i, (min_d, max_d) in enumerate(FLAT_RANGES):
            product_ids = []
            for product in products:
                if product.offers.filter(is_active=True).exists():
                    continue
                # ✅ ONLY flat type
                if product.discount_type != "flat":
                    continue
                discount_amount = product.discount_value or Decimal('0')
                if in_range(discount_amount, min_d, max_d, i == len(FLAT_RANGES) - 1):
                    product_ids.append(product.id)
            product_flat_filters.append({
                "label": f"₹{min_d} - ₹{max_d} Off",
                "min": min_d,
                "max": max_d,
                "product_count": len(product_ids),
                "product_ids": product_ids,
                "product_slugs": [product.slug for product in products if product.id in product_ids]
            })
        # 🔴 OFFER PERCENT FILTER
        for i, (min_p, max_p) in enumerate(PERCENT_RANGES):
            product_ids = []
            for product in products:
                offer = product.offers.filter(is_active=True).first()
                # ✅ ONLY percentage offer
                if not offer or offer.offer_type != "percentage":
                    continue
                base_price = product.price
                final_price = product.get_final_price_with_offer()
                percent = (
                    ((base_price - final_price) / base_price) * 100
                    if base_price else 0
                )
                if in_range(percent, min_p, max_p, i == len(PERCENT_RANGES) - 1):
                    product_ids.append(product.id)
            offer_percent_filters.append({
                "label": f"{min_p}% - {max_p}% Off",
                "min": min_p,
                "max": max_p,
                "product_count": len(product_ids),
                "product_ids": product_ids,
                "slug": f"{min_p}-{max_p}"
            })
        # 🔴 OFFER FLAT FILTER
        for i, (min_d, max_d) in enumerate(FLAT_RANGES):
            product_ids = []
            for product in products:
                offer = product.offers.filter(is_active=True).first()
                # ✅ ONLY flat offer
                if not offer or offer.offer_type != "flat":
                    continue
                base_price = product.price
                final_price = product.get_final_price_with_offer()
                discount_amount = base_price - final_price
                if in_range(discount_amount, min_d, max_d, i == len(FLAT_RANGES) - 1):
                    product_ids.append(product.id)
            offer_flat_filters.append({
                "label": f"₹{min_d} - ₹{max_d} Off",
                "min": min_d,
                "max": max_d,
                "product_count": len(product_ids),
                "product_ids": product_ids
            })
        # ✅ FINAL RESPONSE
        return Response({
            "product_discount": {
                "percentage": product_percent_filters,
                "flat": product_flat_filters
            },
            "offer_discount": {
                "percentage": offer_percent_filters,
                "flat": offer_flat_filters
            }
        })        