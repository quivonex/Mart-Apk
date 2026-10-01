

from dataclasses import field
from itertools import product
import json

from rest_framework.views import APIView # type: ignore
from rest_framework.response import Response # type: ignore
from rest_framework import status # type: ignore
from rest_framework.permissions import IsAuthenticated # type: ignore
from rest_framework_simplejwt.authentication import JWTAuthentication # type: ignore
from agreement.models import CompanyAgreement
from product.products3_upload import upload_file_to_s3
from .models import Category, ProductVariant, ProductVideo, ProductViewHistory, SearchHistory
from django.shortcuts import get_object_or_404 # type: ignore
from .serializers import CategorynameSerializer, LatestProductSerializer, MaterialCategorySerializer, ProductUpdateRequestSerializer, UnitSerializer
from .models import Brand, Unit
from .serializers import BrandSerializer
from .models import SubCategory, Category
from .serializers import SubCategorySerializer
from rest_framework.parsers import MultiPartParser, FormParser # type: ignore


from .models import Product, ProductUpdateRequest
from .serializers import ProductSerializer, ProductApproveSerializer

from product.models import Category, SubCategory, Brand, Unit
from company.models import Company
from branch.models import Branch

from decimal import Decimal
from datetime import datetime

# from .models import StockTransaction


import json
from django.core.serializers.json import DjangoJSONEncoder
from django.db import transaction
from product.s3_upload import clone_file, delete_s3_file
from rest_framework.pagination import PageNumberPagination




class CategoryCreateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = MaterialCategorySerializer(data=request.data)

        if not serializer.is_valid():
            return Response({
                "status": False,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        category = serializer.save(user=request.user)

        response_serializer = MaterialCategorySerializer(category)

        return Response({
            "status": True,
            "message": "Category created successfully",
            "data": response_serializer.data
        }, status=status.HTTP_201_CREATED)



class CategoryUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        category_id = request.data.get("id")

        if not category_id:
            return Response({
                "status": False,
                "message": "Category ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            category = Category.objects.get(id=category_id, user=request.user)
        except Category.DoesNotExist:
            return Response({
                "status": False,
                "message": "Category not found"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = MaterialCategorySerializer(category, data=request.data, partial=True)

        if not serializer.is_valid():
            return Response({
                "status": False,
                "errors": serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        serializer.save()

        return Response({
            "status": True,
            "message": "Category updated successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    

class CategoryListAPIView(APIView):
    # permission_classes = [IsAuthenticated]

    def post(self, request):

        categories = Category.objects.filter(user=request.user)

        serializer = MaterialCategorySerializer(categories, many=True)

        return Response({
            "status": True,
            "message": "Categories fetched successfully",
            "data": serializer.data
        }, status=200)



class CategorynameListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):

        categories = Category.objects.filter(user=request.user)

        serializer = CategorynameSerializer(categories, many=True)

        return Response({
            "status": True,
            "message": "Categories fetched successfully",
            "data": serializer.data
        }, status=200)
    


class AllCategoryListAPIView(APIView):

    def post(self, request):

        categories = Category.objects.all()

        serializer = MaterialCategorySerializer(categories, many=True)

        return Response({
            "status": True,
            "message": "All categories fetched successfully",
            "data": serializer.data
        }, status=200)

class CategoryByCompanyAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    def post(self, request):
        company_id = request.data.get("company_id")

        if not company_id:
            return Response(
                {"status": False, "message": "Company id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        categories = Category.objects.filter(company_id=company_id, is_active=True)

        serializer = MaterialCategorySerializer(categories, many=True)

        return Response(
            {
                "status": True,
                "message": "Categories fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


class CategorySoftDeleteAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        category_id = request.data.get("id")

        if not category_id:
            return Response({
                "status": False,
                "message": "Category ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔐 Only user's category
        category = get_object_or_404(
            Category,
            id=category_id
        )

        if not category.is_active:
            return Response({
                "status": False,
                "message": "Category already deleted"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔥 Soft delete
        category.is_active = False
        category.save()

        return Response({
            "status": True,
            "message": "Category soft deleted successfully"
        }, status=status.HTTP_200_OK)

class CategoryRestoreAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        category_id = request.data.get("id")

        if not category_id:
            return Response({
                "status": False,
                "message": "Category ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔐 Only user's category
        category = get_object_or_404(
            Category,
            id=category_id
        )

        if category.is_active:
            return Response({
                "status": False,
                "message": "Category is already active"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔥 Restore
        category.is_active = True
        category.save()

        return Response({
            "status": True,
            "message": "Category restored successfully"
        }, status=status.HTTP_200_OK)


class SubCategoryCreateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user
        category_id = request.data.get("category")
        name = request.data.get("name")
        description = request.data.get("description")

        if not category_id:
            return Response(
                {"status": False, "message": "Category id required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            category = Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            return Response(
                {"status": False, "message": "Category not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        subcategory = SubCategory.objects.create(
            user=user,
            category=category,
            name=name,
            description=description
        )

        serializer = SubCategorySerializer(subcategory)

        return Response(
            {
                "status": True,
                "message": "SubCategory created successfully",
                "data": serializer.data
            },
            status=status.HTTP_201_CREATED
        )


class SubCategoryUpdateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user
        subcategory_id = request.data.get("id")

        if not subcategory_id:
            return Response(
                {"status": False, "message": "SubCategory id required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            subcategory = SubCategory.objects.get(id=subcategory_id, user=user)
        except SubCategory.DoesNotExist:
            return Response(
                {"status": False, "message": "SubCategory not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        category_id = request.data.get("category")

        if category_id:
            try:
                category = Category.objects.get(id=category_id)
                subcategory.category = category
            except Category.DoesNotExist:
                return Response(
                    {"status": False, "message": "Category not found"},
                    status=status.HTTP_404_NOT_FOUND
                )

        subcategory.name = request.data.get("name", subcategory.name)
        subcategory.description = request.data.get("description", subcategory.description)

        subcategory.save()

        serializer = SubCategorySerializer(subcategory)

        return Response(
            {
                "status": True,
                "message": "SubCategory updated successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )


class SubCategoryallListAPIView(APIView):

    def post(self, request):
        subcategories = SubCategory.objects.all().order_by('-id')
        serializer = SubCategorySerializer(subcategories, many=True)

        return Response({
            "status": True,
            "message": "SubCategory list fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)


    
class SubCategoryListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user

        subcategories = SubCategory.objects.filter(
            user=user
        ).order_by('-id')

        serializer = SubCategorySerializer(subcategories, many=True)

        return Response({
            "status": True,
            "message": "SubCategory list fetched successfully",
            "count": subcategories.count(),
            "data": serializer.data
        })


class UserSubCategoryListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 🔐 Filter by logged-in user + active
        subcategories = SubCategory.objects.filter(
            user=request.user
        ).order_by('-id')

        serializer = SubCategorySerializer(subcategories, many=True)

        return Response({
            "status": True,
            "message": "SubCategory list fetched successfully",
            "count": subcategories.count(),
            "data": serializer.data
        })


class SubCategorySoftDeleteAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subcategory_id = request.data.get("id")

        if not subcategory_id:
            return Response({
                "status": False,
                "message": "SubCategory id required"
            }, status=400)

        subcategory = get_object_or_404(
            SubCategory,
            id=subcategory_id
        )

        if not subcategory.is_active:
            return Response({
                "status": False,
                "message": "SubCategory already deleted"
            }, status=400)

        # 🔥 Soft delete
        subcategory.is_active = False
        subcategory.save()

        return Response({
            "status": True,
            "message": "SubCategory soft deleted successfully"
        }, status=200)


class SubCategoryRestoreAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subcategory_id = request.data.get("id")

        if not subcategory_id:
            return Response({
                "status": False,
                "message": "SubCategory id required"
            }, status=400)

        subcategory = get_object_or_404(
            SubCategory,
            id=subcategory_id
        )

        if subcategory.is_active:
            return Response({
                "status": False,
                "message": "SubCategory is already active"
            }, status=400)

        # 🔥 Restore
        subcategory.is_active = True
        subcategory.save()

        return Response({
            "status": True,
            "message": "SubCategory restored successfully"
        }, status=200)



class SubCategoryByCategoryAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        category_id = request.data.get("category")

        if not category_id:
            return Response(
                {"status": False, "message": "Category id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            category = Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            return Response(
                {"status": False, "message": "Category not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        subcategories = SubCategory.objects.filter(
            category=category,
            is_active=True
        )

        serializer = SubCategorySerializer(subcategories, many=True)

        return Response(
            {
                "status": True,
                "message": "SubCategories fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
    


class ProductsBySubCategoryAPI(APIView):

    def post(self, request):
        subcategory_id = request.data.get('subcategory_id')

        # ✅ validation
        if not subcategory_id:
            return Response(
                {"error": "subcategory_id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ✅ filter ONLY approved products
        products = Product.objects.filter(
            subcategory_id=subcategory_id,
            is_active=True,
            status='approved'   # 🔥 important line
        )

        if not products.exists():
            return Response(
                {"message": "No approved products found"},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": "success",
            "count": len(serializer.data),
            "products": serializer.data
        })    
            

class BrandCreateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user
        name = request.data.get("name")
        description = request.data.get("description")
        category_id = request.data.get("category")
        subcategory_id = request.data.get("subcategory")

        if not name:
            return Response(
                {"status": False, "message": "Name is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not category_id:
            return Response(
                {"status": False, "message": "Category is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not subcategory_id:
            return Response(
                {"status": False, "message": "SubCategory is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            category = Category.objects.get(id=category_id)
        except Category.DoesNotExist:
            return Response(
                {"status": False, "message": "Category not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        try:
            subcategory = SubCategory.objects.get(id=subcategory_id)
        except SubCategory.DoesNotExist:
            return Response(
                {"status": False, "message": "SubCategory not found"},
                status=status.HTTP_404_NOT_FOUND
            )

        brand = Brand.objects.create(
            user=user,
            category=category,
            subcategory=subcategory,
            name=name,
            description=description
        )

        serializer = BrandSerializer(brand)

        return Response(
            {
                "status": True,
                "message": "Brand created successfully",
                "data": serializer.data
            },
            status=status.HTTP_201_CREATED
        )

class BrandUpdateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        brand_id = request.data.get("id")

        if not brand_id:
            return Response({
                "message": "Brand ID is required!"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            brand = Brand.objects.get(id=brand_id)
        except Brand.DoesNotExist:
            return Response({
                "message": "Brand not found!"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = BrandSerializer(brand, data=request.data, partial=True)

        if serializer.is_valid():
            updated_brand = serializer.save()
            return Response({
                "message": "Brand updated successfully!",
                "brand": serializer.data
            }, status=status.HTTP_200_OK)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)    




class BrandListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user

        brands = Brand.objects.filter(user=user).order_by("-created_at")

        serializer = BrandSerializer(brands, many=True)

        return Response(
            {
                "status": True,
                "message": "Brand list fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
    


class BrandallListAPIView(APIView):

    def post(self, request):

        brands = Brand.objects.filter(is_active=True).order_by("-created_at")

        serializer = BrandSerializer(brands, many=True)

        return Response(
            {
                "status": True,
                "message": "Brand list fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )

class BrandBySubCategoryAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        subcategory_id = request.data.get("subcategory_id")

        if not subcategory_id:
            return Response(
                {"status": False, "message": "SubCategory id is required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        brands = Brand.objects.filter(subcategory_id=subcategory_id, is_active=True)

        serializer = BrandSerializer(brands, many=True)

        return Response(
            {
                "status": True,
                "message": "Brands fetched successfully",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )    


# SOFT DELETE BRAND
class BrandSoftDeleteAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        brand_id = request.data.get("id")

        if not brand_id:
            return Response({
                "status": False,
                "message": "Brand id is required"
            }, status=400)

        # 🔐 Restrict to logged-in user's brand
        brand = get_object_or_404(
            Brand,
            id=brand_id
        )

        if not brand.is_active:
            return Response({
                "status": False,
                "message": "Brand already deleted"
            }, status=400)

        # 🔥 Soft delete
        brand.is_active = False
        brand.save()

        return Response({
            "status": True,
            "message": "Brand soft deleted successfully"
        }, status=200)


# RESTORE BRAND
class BrandRestoreAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        brand_id = request.data.get("id")

        if not brand_id:
            return Response({
                "status": False,
                "message": "Brand id is required"
            }, status=400)

        # 🔐 Restrict to logged-in user's brand
        brand = get_object_or_404(
            Brand,
            id=brand_id,
            user=request.user
        )

        if brand.is_active:
            return Response({
                "status": False,
                "message": "Brand is already active"
            }, status=400)

        # 🔥 Restore
        brand.is_active = True
        brand.save()

        return Response({
            "status": True,
            "message": "Brand restored successfully"
        }, status=200)

from .models import Product, ProductImage
from .serializers import ProductSerializer
from .products3_upload import upload_file_to_s3







class ProductCreateAPIView(APIView):
    """
    Product Create API with S3 uploads for thumbnail, images, videos,
    and variant-specific images with unique SKU handling.
    """
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, *args, **kwargs):
        print("FILES received:", request.FILES)

        # --------------------------
        # Parse variants JSON
        # --------------------------
        variants = json.loads(request.data.get('variants', '[]'))
        print("Received variants:", variants)

        # --------------------------
        # Save main product
        # --------------------------
        serializer = ProductSerializer(data=request.data)
        if serializer.is_valid():
            # Save product first
            product = serializer.save(is_active=True)

            # --------------------------
            # GENERATE SLUG AND SAVE COMPLETELY
            # --------------------------
            if not product.slug:
                base_slug = slugify(product.name)
                unique_slug = base_slug
                counter = 1
                while Product.objects.filter(slug=unique_slug).exists():
                    unique_slug = f"{base_slug}-{counter}"
                    counter += 1
                product.slug = unique_slug
                product.save()  # FULL save - not just update_fields
                print(f"Generated slug: {product.slug}")

            # --------------------------
            # Thumbnail Upload
            # --------------------------
            thumbnail_file = request.FILES.get('thumbnail')
            if thumbnail_file:
                thumbnail_url = upload_file_to_s3(thumbnail_file, folder='products/thumbnails')
                if thumbnail_url:
                    product.thumbnail_s3_key = thumbnail_url
                    product.save(update_fields=['thumbnail_s3_key'])
                    print("Thumbnail uploaded:", thumbnail_url)

            # --------------------------
            # Main Product Images
            # --------------------------
            images = request.FILES.getlist('images')
            product_images = []
            if images:
                for img in images:
                    img_url = upload_file_to_s3(img, folder='products/images')
                    if img_url:
                        img_obj = ProductImage.objects.create(product=product, image_s3_key=img_url)
                        product_images.append(img_obj)
                        print("Image uploaded:", img_url)

            # --------------------------
            # Videos
            # --------------------------
            videos = request.FILES.getlist('videos')
            if videos:
                for video in videos:
                    video_url = upload_file_to_s3(video, folder='products/videos')
                    if video_url:
                        ProductVideo.objects.create(product=product, video_s3_key=video_url)
                        print("Video uploaded:", video_url)

            # --------------------------
            # Helper: Generate unique SKU
            # --------------------------
            def generate_unique_sku(base_sku):
                counter = 1
                new_sku = base_sku
                while ProductVariant.objects.filter(sku=new_sku).exists():
                    new_sku = f"{base_sku}-{counter}"
                    counter += 1
                return new_sku

            # --------------------------
            # Variant-specific Images + Variants
            # --------------------------
            for idx, variant in enumerate(variants):
                # Variant image
                image_file = request.FILES.get(f'variant_image_{idx}')
                image_index = variant.get('image_index', 0)

                if image_file:
                    variant_img_url = upload_file_to_s3(image_file, folder='products/variant_images')
                    img_obj = ProductImage.objects.create(product=product, image_s3_key=variant_img_url)
                    if img_obj in product_images:
                        image_index = product_images.index(img_obj)
                    else:
                        product_images.append(img_obj)
                        image_index = len(product_images) - 1

                # Handle SKU uniqueness
                sku = variant.get('sku', '')
                if sku:
                    sku = generate_unique_sku(sku)

                ProductVariant.objects.create(
                    product=product,  # Now product is fully saved
                    attributes=variant.get('attributes', {}),
                    price=variant.get('price', 0),
                    stock_quantity=variant.get('stock_quantity', 0) or variant.get('stock', 0),
                    sku=sku,
                    image_index=image_index
                )

            product.refresh_from_db()
            response_data = ProductSerializer(product).data
            
            return Response({
                "status": True,
                "message": "Product created successfully",
                "product": response_data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    
    
    
    
    
    
    
    
    
    
    
# class ProductDetailAPIView(APIView):
#     """
#     Get single product details
#     """

#     def post(self, request, *args, **kwargs):

#         product_id = request.data.get("id")

#         if not product_id:
#             return Response(
#                 {
#                     "status": "error",
#                     "message": "Product id is required"
#                 },
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         product = Product.objects.filter(id=product_id).first()

#         if not product:
#             return Response(
#                 {
#                     "status": "error",
#                     "message": "Product not found"
#                 },
#                 status=status.HTTP_404_NOT_FOUND
#             )

#         serializer = ProductSerializer(product)

#         return Response(
#             {
#                 "status": "success",
#                 "product": serializer.data
#             },
#             status=status.HTTP_200_OK
#         )
class ProductDetailAPIView(APIView):
    """
    Get single product details by ID or Slug
    """
    
    def post(self, request, *args, **kwargs):
        # request मधून id किंवा slug घ्या
        product_id = request.data.get("id")
        product_slug = request.data.get("slug")
        
        # किमान एक तरी हवं
        if not product_id and not product_slug:
            return Response(
                {
                    "status": "error",
                    "message": "Either 'id' or 'slug' is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # id किंवा slug वापरून product शोधा
        try:
            if product_id:
                # id ने शोधा
                product = Product.objects.get(id=product_id)
            else:
                # slug ने शोधा
                product = Product.objects.get(slug=product_slug)
        except Product.DoesNotExist:
            return Response(
                {
                    "status": "error",
                    "message": "Product not found"
                },
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Product found - serialized data return करा
        serializer = ProductSerializer(product)
        
        return Response({
            "status": "success",
            "message": "Product details retrieved successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
        # # ✅ 🔥 NEW CODE (SAFE - existing logic la kahi effect nahi)
        # try:
        #     if request.user.is_authenticated:
        #         ProductViewHistory.objects.update_or_create(
        #             user=request.user,
        #             product=product
        #         )
        # except Exception as e:
        #     print("History save error:", e)

        # 🔒 Existing code (same)
        serializer = ProductSerializer(product)

        return Response(
            {
                "status": "success",
                "product": serializer.data
            },
            status=status.HTTP_200_OK
        )
        


from urllib.parse import urlencode

class ProductReferralLinkAPIView(APIView):
    def post(self, request):
        # request मधून product_id आणि referral_code घ्या
        product_id = request.data.get('product_id')
        referral_code = request.data.get('referral_code')  # marketing partner चा code
        
        if not product_id:
            return Response({
                "status": False,
                "message": "product_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # प्रॉडक्ट मिळवा
        try:
            product = Product.objects.get(id=product_id)
        except Product.DoesNotExist:
            return Response({
                "status": False,
                "message": "Product not found"
            }, status=status.HTTP_404_NOT_FOUND)
        
        # स्लग किंवा id वापरा
        identifier = product.slug if product.slug else str(product.id)
        
        # URL पॅरामीटर्स तयार करा
        params = {
            'product': identifier,
        }
        
        # जर referral_code असेल तर तो add करा
        if referral_code:
            params['ref_code'] = referral_code
        
        # लिंक तयार करा
        base_url = "https://qnxmartb2b.com/product-enquiry"
        query_string = urlencode(params)
        referral_link = f"{base_url}?{query_string}"
        
        return Response({
            "status": True,
            "product_id": product.id,
            "product_name": product.name,
            "slug": product.slug,
            "referral_code": referral_code,
            "referral_link": referral_link,
            "message": "Referral link generated successfully"
        }, status=status.HTTP_200_OK)
        
class ProductListAPIView(APIView):
    """
    Get all products with images and thumbnail
    """

    def post(self, request, *args, **kwargs):
        products = Product.objects.all().order_by('-id')
        serializer = ProductSerializer(products, many=True)

        

        return Response({
            "status": "success",
            "count": products.count(),
            "products": serializer.data
        }, status=status.HTTP_200_OK)   
    


class AdminPendingProductListAPIView(APIView):

    def post(self, request):

        products = Product.objects.filter(status='pending').order_by('-created_at')

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Pending products fetched successfully",
            "count": products.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)  


class ApprovedProductListAPIView(APIView):

    def post(self, request):

        products = Product.objects.filter(status='approved', is_active=True).order_by('-created_at')

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Approved products fetched successfully",
            "count": products.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    

from django.conf import settings
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.core.mail import EmailMultiAlternatives
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from django.core.mail import send_mail

class ApproveProductAPIView(APIView):

    def post(self, request):

        product_id = request.data.get("product_id")

        if not product_id:
            return Response({
                "status": False,
                "message": "Product ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            product = Product.objects.get(id=product_id)

            # Update Product Status
            product.status = "approved"
            product.save()

            # Get User Email
            user = product.company.user
            user_email = user.email

            # HTML Email Context
            context = {
                "user_name": user.get_full_name() if user.get_full_name() else user.username,
                "product_name": product.name,
                "company_name": product.company.name,
                "dashboard_url": "https://qnxmartb2b.com/companyadmin/"
            }

            # Render HTML Template
            html_message = render_to_string(
                "emails/product_approved.html",
                context
            )

            # Plain Text Version
            plain_message = strip_tags(html_message)

            # Send Email
            email = EmailMultiAlternatives(
                subject="🎉 Congratulations! Your Product Has Been Approved",
                body=plain_message,
                from_email=settings.EMAIL_HOST_USER,
                to=[user_email],
            )

            email.attach_alternative(html_message, "text/html")
            email.send()

            return Response({
                "status": True,
                "message": "Product approved and email sent successfully."
            }, status=status.HTTP_200_OK)

        except Product.DoesNotExist:
            return Response({
                "status": False,
                "message": "Product not found"
            }, status=status.HTTP_404_NOT_FOUND)

        except Exception as e:
            return Response({
                "status": False,
                "message": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class RejectProductAPIView(APIView):

    def post(self, request):

        product_id = request.data.get("product_id")
        reject_reason = request.data.get("reject_reason")

        if not product_id:
            return Response({
                "status": False,
                "message": "Product ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        if not reject_reason:
            return Response({
                "status": False,
                "message": "Reject reason is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            product = Product.objects.get(id=product_id)

            # Update Product Status
            product.status = "rejected"
            product.save()

            user = product.company.user
            user_email = user.email

            # HTML Context
            context = {
                "user_name": user.get_full_name() if user.get_full_name() else user.username,
                "product_name": product.name,
                "company_name": product.company.name,
                "reject_reason": reject_reason,
                "dashboard_url": "https://qnxmartb2b.com/companyadmin/"
            }

            # Render HTML Template
            html_message = render_to_string(
                "emails/product_rejected.html",
                context
            )

            plain_message = strip_tags(html_message)

            email = EmailMultiAlternatives(
                subject="❌ Your Product Has Been Rejected",
                body=plain_message,
                from_email=settings.EMAIL_HOST_USER,
                to=[user_email]
            )

            email.attach_alternative(html_message, "text/html")
            email.send()

            return Response({
                "status": True,
                "message": "Product rejected and email sent successfully."
            }, status=status.HTTP_200_OK)

        except Product.DoesNotExist:
            return Response({
                "status": False,
                "message": "Product not found"
            }, status=status.HTTP_404_NOT_FOUND)

        except Exception as e:
            return Response({
                "status": False,
                "message": str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
class DeleteApprovedProductAPIView(APIView):
    def post(self, request):

        product_id = request.data.get("product_id")

        if not product_id:
            return Response(
                {"status": False, "message": "Product ID required"},
                status=400
            )

        product = Product.objects.filter(id=product_id, status='approved').first()

        if not product:
            return Response(
                {"status": False, "message": "Approved product not found"},
                status=404
            )

        product.delete()

        return Response({
            "status": True,
            "message": "Approved product deleted successfully"
        })        
        
class UnitCreateAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        serializer = UnitSerializer(data=request.data)

        if serializer.is_valid():
            serializer.save(user=request.user)

            return Response({
                "status": True,
                "message": "Unit created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

class UnitUpdateAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        unit_id = request.data.get('id')

        if not unit_id:
            return Response({
                "status": False,
                "message": "Unit id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        unit = get_object_or_404(Unit, id=unit_id)

        serializer = UnitSerializer(
            unit,
            data=request.data,
            partial=True   # only update provided fields
        )

        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": True,
                "message": "Unit updated successfully",
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

class UnitSoftDeleteAPIView(APIView):

    def post(self, request):
        unit_id = request.data.get('id')

        if not unit_id:
            return Response({
                "status": False,
                "message": "Unit id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        unit = get_object_or_404(Unit, id=unit_id)

        # Soft delete
        unit.is_active = False
        unit.save()

        return Response({
            "status": True,
            "message": "Unit soft deleted successfully"
        }, status=status.HTTP_200_OK)        


class UnitRestoreAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        unit_id = request.data.get('id')

        if not unit_id:
            return Response({
                "status": False,
                "message": "Unit id is required"
            }, status=400)

        unit = get_object_or_404(
            Unit,
            id=unit_id
        )

        if unit.is_active:
            return Response({
                "status": False,
                "message": "Unit is already active"
            }, status=400)

        unit.is_active = True
        unit.save()

        return Response({
            "status": True,
            "message": "Unit restored successfully"
        }, status=200)


class UnitListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        # Filter units by logged-in user
        units = Unit.objects.filter(user=request.user).order_by('id')
        serializer = UnitSerializer(units, many=True)

        return Response({
            "status": True,
            "message": "Unit list fetched successfully",
            "count": units.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class UnitallListAPIView(APIView):

    def post(self, request):
        units = Unit.objects.all().order_by('id')

        serializer = UnitSerializer(units, many=True)

        return Response({
            "status": True,
            "message": "Unit list fetched successfully",
            "count": units.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    
# RETRIEVE (by name)
class UnitRetrieveAPIView(APIView):
    def post(self, request):
        name = request.data.get("name")

        if not name:
            return Response({"error": "Name is required"}, status=400)

        try:
            unit = Unit.objects.get(name=name)
        except Unit.DoesNotExist:
            return Response({"error": "Unit not found"}, status=404)

        serializer = UnitSerializer(unit)
        return Response(serializer.data)



# latest product serializer for listing products with company, category, subcategory names and thumbnail url
class LatestProductAPIView(APIView):

    def post(self, request):

        products = Product.objects.filter(is_active=True)\
                    .order_by('-created_at')[:5]

        serializer = LatestProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Latest products fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class LatestProductAPIViewAuth(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        products = Product.objects.filter(
            is_active=True,
            status='approved'
        ).order_by('-created_at')[:5]

        serializer = LatestProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Latest products fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    

class LatestApprovedProductAPIView(APIView):

    def post(self, request):
        """
        Fetch latest 5 approved and active products
        """
        products = Product.objects.filter(
            is_active=True,
            status='approved'   # ✅ only approved products
        ).order_by('-created_at')[:5]  # latest 5

        serializer = LatestProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Latest approved products fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)    
    
class ApprovedProductCountAPIView(APIView):

    def post(self, request):
        count = Product.objects.filter(status='approved').count()

        return Response({
            "status": True,
            "approved_product_count": count
        }, status=200)    


from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Product

class RelatedProductsView(APIView):
    def post(self, request):
        try:
            product_id = request.data.get("product_id")

            if not product_id:
                return Response({
                    "status": "error",
                    "message": "product_id is required"
                })

            product = Product.objects.get(id=product_id)

            related = Product.objects.filter(
                is_active=True,
                status='approved'
            ).exclude(id=product.id)

            # Priority logic
            if product.subcategory:
                related = related.filter(subcategory=product.subcategory)
            elif product.category:
                related = related.filter(category=product.category)

            related = related[:10]

            data = [{
                "id": p.id,
                "name": p.name,
                "slug": p.slug,
                "price": p.price,
                "thumbnail": p.thumbnail_s3_key
            } for p in related]

            return Response({
                "status": "success",
                "products": data
            })

        except Product.DoesNotExist:
            return Response({
                "status": "error",
                "message": "Product not found"
            })

# # 
from django.db.models import Q

class ProductSearchAPIView(APIView):

    def post(self, request):
        search_text = request.data.get("search")

        if not search_text:
            return Response({
                "status": False,
                "message": "Search text is required"
            })

        # ✅ 🔥 SAVE SEARCH HISTORY
        try:
            if request.user.is_authenticated:
                SearchHistory.objects.create(
                    user=request.user,
                    search_text=search_text
                )
        except Exception as e:
            print("Search save error:", e)

        # 🔍 SEARCH LOGIC
        keywords = search_text.split()
        query = Q()

        for keyword in keywords:
            query |= Q(name__icontains=keyword)
            query |= Q(category__name__icontains=keyword)
            query |= Q(subcategory__name__icontains=keyword)
            query |= Q(brand__name__icontains=keyword)

        products = Product.objects.filter(query, status='approved').distinct()

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Search results",
            "count": len(serializer.data),
            "data": serializer.data
        })
    

# class RecommendedProductAPIView(APIView):

#     def post(self, request):
#         user = request.user

#         if not user.is_authenticated:
#             return Response({
#                 "status": False,
#                 "data": []
#             })

#         # 🔹 last 5 searches ghe
#         searches = SearchHistory.objects.filter(user=user)\
#                     .order_by('-searched_at')[:5]

#         if not searches:
#             products = Product.objects.filter(status='approved')[:5]
#             serializer = ProductSerializer(products, many=True)
#             return Response({"status": True, "data": serializer.data})

#         query = Q()

#         for s in searches:
#             keywords = s.search_text.split()

#             for keyword in keywords:
#                 query |= Q(name__icontains=keyword)
#                 query |= Q(category__name__icontains=keyword)
#                 query |= Q(brand__name__icontains=keyword)

#         products = Product.objects.filter(query, status='approved')\
#                     .distinct()[:20]

#         serializer = ProductSerializer(products, many=True)

#         return Response({
#             "status": True,
#             "message": "Recommended from search history",
#             "data": serializer.data
#         })
    

class RecentlyViewedProductsAPIView(APIView):

    def post(self, request):
        user = request.user

        if not user.is_authenticated:
            return Response({
                "status": False,
                "message": "User not authenticated",
                "data": []
            })

        viewed = ProductViewHistory.objects.filter(user=user)\
                    .order_by('-viewed_at')[:5]

        product_ids = [v.product.id for v in viewed]

        products = Product.objects.filter(id__in=product_ids)

        products = sorted(products, key=lambda x: product_ids.index(x.id))

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Recently viewed products",
            "data": serializer.data
        })
    


 
# views.py

from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView
from rest_framework.response import Response
from .models import Product, ProductViewHistory
 
class TrackProductViewAPIView(APIView):

    permission_classes = [IsAuthenticated]
 
    def post(self, request):

        user = request.user

        product_id = request.data.get('product_id')
 
        if not product_id:

            return Response({

                "status": False,

                "message": "Product ID required"

            })
 
        try:

            product = Product.objects.get(id=product_id)
 
            # 🔥 create OR update (duplicate avoid)

            ProductViewHistory.objects.update_or_create(

                user=user,

                product=product

            )
 
            return Response({

                "status": True,

                "message": "Product view tracked"

            })

        except Product.DoesNotExist:

            return Response({

                "status": False,

                "message": "Product not found"

            })



# ############################## COMPANY PRODUCTS ##########################
# class     CompanyProductListAPIView(APIView):
#     authentication_classes = [JWTAuthentication]
#     permission_classes = [IsAuthenticated]

#     def post(self, request):
#         user = request.user
#         branch_id = request.data.get("branch_id")  # 🔥 new
#         # 🔥 Base queryset (company products)
#         products = Product.objects.filter(
#             company__user=user,
#             is_active=True,
#             status='approved'
#         )
#         # 🔥 Apply branch filter if provided
#         if branch_id:
#             products = products.filter(branch_id=branch_id)
#         products = products.order_by('-id')
#         serializer = ProductSerializer(products, many=True)
#         return Response({
#             "status": True,
#             "message": "Products fetched successfully",
#             "count": products.count(),
#             "data": serializer.data
#         }, status=status.HTTP_200_OK)


class CompanyProductListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        company_id = request.data.get("company_id")
        from company.models import Company
        # 🔥 CASE 1: company_id provided
        if company_id:
            company = Company.objects.filter(id=company_id, user=user).first()
            if not company:
                return Response({
                    "status": False,
                    "message": "Company not found or not belongs to user"
                }, status=404)
            products = Product.objects.filter(
                company=company,
                is_active=True,
                status='approved'
            )
        # 🔥 CASE 2: NO company_id → all user companies
        else:
            products = Product.objects.filter(
                company__user=user,
                is_active=True,
                status='approved'
            )
        products = products.order_by('-id')
        serializer = ProductSerializer(products, many=True)
        return Response({
            "status": True,
            "message": "Products fetched successfully",
            "count": products.count(),
            "data": serializer.data
        }, status=200)
        
class ProductActiveInactiveAPIView(APIView):

    def post(self, request):

        product_id = request.data.get("product_id")
        is_active = request.data.get("is_active")

        if not product_id:
            return Response(
                {
                    "success": False,
                    "message": "product_id is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if is_active is None:
            return Response(
                {
                    "success": False,
                    "message": "is_active is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # Convert string values from form-data
        if isinstance(is_active, str):
            is_active = is_active.lower() in ["true", "1", "yes"]

        try:
            product = Product.objects.get(id=product_id)
        except Product.DoesNotExist:
            return Response(
                {
                    "success": False,
                    "message": "Product not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        product.is_active = is_active
        product.save(update_fields=["is_active"])

        return Response(
            {
                "success": True,
                "message": (
                    "Product activated successfully."
                    if product.is_active
                    else "Product deactivated successfully."
                ),
                "product_id": product.id,
                "is_active": product.is_active
            },
            status=status.HTTP_200_OK
        )        

# PRODUCT UPDATE REQUEST
class ProductUpdateAPIView(APIView):
    """
    Product Update API (ID from request body)
    """
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request, *args, **kwargs):
        import json
        # --------------------------
        # Get product ID from request
        # --------------------------
        product_id = request.data.get('product_id')
        if not product_id:
            return Response({
                "status": False,
                "message": "Product ID is required"
            }, status=400)
        try:
            product = Product.objects.get(id=product_id)
        except Product.DoesNotExist:
            return Response({
                "status": False,
                "message": "Product not found"
            }, status=404)
        # --------------------------
        # Parse variants JSON
        # --------------------------
        variants = json.loads(request.data.get('variants', '[]'))
        # --------------------------
        # Update product
        # --------------------------
        serializer = ProductSerializer(product, data=request.data, partial=True)
        if serializer.is_valid():
            product = serializer.save()
            # --------------------------
            # Thumbnail Update
            # --------------------------
            thumbnail_file = request.FILES.get('thumbnail')
            if thumbnail_file:
                thumbnail_url = upload_file_to_s3(thumbnail_file, folder='products/thumbnails')
                if thumbnail_url:
                    product.thumbnail_s3_key = thumbnail_url
                    product.save()
            # --------------------------
            # Images Add
            # --------------------------
            product_images = list(ProductImage.objects.filter(product=product))
            images = request.FILES.getlist('images')
            for img in images:
                img_url = upload_file_to_s3(img, folder='products/images')
                if img_url:
                    img_obj = ProductImage.objects.create(product=product, image_s3_key=img_url)
                    product_images.append(img_obj)
            # --------------------------
            # Delete Images
            # --------------------------
            delete_image_ids = request.data.getlist('delete_images')
            if delete_image_ids:
                ProductImage.objects.filter(id__in=delete_image_ids, product=product).delete()
            # --------------------------
            # Videos Add
            # --------------------------
            videos = request.FILES.getlist('videos')
            for video in videos:
                video_url = upload_file_to_s3(video, folder='products/videos')
                if video_url:
                    ProductVideo.objects.create(product=product, video_s3_key=video_url)
            # -------------------------
            # Delete Videos
            # --------------------------
            delete_video_ids = request.data.getlist('delete_videos')
            if delete_video_ids:
                ProductVideo.objects.filter(id__in=delete_video_ids, product=product).delete()
            # --------------------------
            # SKU generator
            # --------------------------
            def generate_unique_sku(base_sku, exclude_id=None):
                counter = 1
                new_sku = base_sku
                while ProductVariant.objects.filter(sku=new_sku).exclude(id=exclude_id).exists():
                    new_sku = f"{base_sku}-{counter}"
                    counter += 1
                return new_sku
            # --------------------------
            # Variants Handling
            # --------------------------
            existing_variant_ids = []
            for idx, variant in enumerate(variants):
                variant_id = variant.get('id')
                image_file = request.FILES.get(f'variant_image_{idx}')
                image_index = variant.get('image_index', 0)
                if image_file:
                    variant_img_url = upload_file_to_s3(image_file, folder='products/variant_images')
                    img_obj = ProductImage.objects.create(product=product, image_s3_key=variant_img_url)
                    product_images.append(img_obj)
                    image_index = len(product_images) - 1
                sku = variant.get('sku', '')
                if sku:
                    sku = generate_unique_sku(sku, variant_id)
                if variant_id:
                    # UPDATE
                    try:
                        obj = ProductVariant.objects.get(id=variant_id, product=product)
                        obj.attributes = variant.get('attributes', {})
                        obj.price = variant.get('price', 0)
                        obj.stock_quantity = variant.get('stock_quantity', 0) or variant.get('stock', 0)
                        obj.sku = sku
                        obj.image_index = image_index
                        obj.save()
                        existing_variant_ids.append(obj.id)
                    except ProductVariant.DoesNotExist:
                        pass
                else:
                    # CREATE
                    obj = ProductVariant.objects.create(
                        product=product,
                        attributes=variant.get('attributes', {}),
                        price=variant.get('price', 0),
                        stock_quantity=variant.get('stock_quantity', 0) or variant.get('stock', 0),
                        sku=sku,
                        image_index=image_index
                    )
                    existing_variant_ids.append(obj.id)
            # --------------------------
            # Delete removed variants
            # --------------------------
            ProductVariant.objects.filter(product=product).exclude(id__in=existing_variant_ids).delete()
            product.refresh_from_db()
            return Response({
                "status": True,
                "message": "Product updated successfully",
                "product": ProductSerializer(product).data
            }, status=200)
        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=400)

class ProductUpdateRequestAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    
    parser_classes = (MultiPartParser, FormParser)
    def post(self, request):
        import json
        product_id = request.data.get('product_id')
        if not product_id:
            return Response({"status": False, "message": "Product ID required"}, status=400)
        try:
            product = Product.objects.get(id=product_id)
        except Product.DoesNotExist:
            return Response({"status": False, "message": "Product not found"}, status=404)
        
        if not product.company or product.company.user != request.user:
            return Response({
                "status": False,
                "message": "You are not allowed to update this product"
            }, status=403)
        
        if ProductUpdateRequest.objects.filter(product=product, status='pending').exists():
            return Response({
                "status": False,
                "message": "Request already pending"
            }, status=400)
        variants = json.loads(request.data.get('variants', '[]'))
        # --------------------------
        # 🔥 HANDLE FILES USING CLONE
        # --------------------------
        thumbnail_url = None
        thumbnail_file = request.FILES.get('thumbnail')
        if thumbnail_file:
            thumbnail_url = upload_file_to_s3(
                clone_file(thumbnail_file),
                'products/thumbnails'
            )
        image_urls = []
        for img in request.FILES.getlist('images'):
            url = upload_file_to_s3(
                clone_file(img),
                'products/images'
            )
            if url:
                image_urls.append(url)
        video_urls = []
        for vid in request.FILES.getlist('videos'):
            url = upload_file_to_s3(
                clone_file(vid),
                'products/videos'
            )
            if url:
                video_urls.append(url)
        # --------------------------
        # Variant images
        # --------------------------
        for idx, variant in enumerate(variants):
            file_key = f'variant_image_{idx}'
            variant_file = request.FILES.get(file_key)
            if variant_file:
                variant['image_url'] = upload_file_to_s3(
                    clone_file(variant_file),
                    'products/variant_images'
                )
        # --------------------------
        # SAFE product_data
        # --------------------------
        product_data = {}
        for key in request.data.keys():
            if key not in request.FILES:
                product_data[key] = request.data.get(key)
        # --------------------------
        # SAVE REQUEST
        # --------------------------
        ProductUpdateRequest.objects.create(
            product=product,
            requested_by=request.user,
            updated_data={
                "product_data": product_data,
                "thumbnail": thumbnail_url,
                "images": image_urls,
                "videos": video_urls,
                "variants": variants,
                "delete_images": request.data.getlist('delete_images'),
                "delete_videos": request.data.getlist('delete_videos')
            }
        )
        return Response({
            "status": True,
            "message": "Update request sent for approval"
        })



class ApproveProductUpdateAPIView(APIView):

    def post(self, request):
        request_id = request.data.get("request_id")

        if not request_id:
            return Response({
                "status": False,
                "message": "request_id is required"
            }, status=400)

        try:
            update_request = ProductUpdateRequest.objects.select_related(
                "product__company", "product"
            ).get(id=request_id)   # 🔁 MODIFIED
        except ProductUpdateRequest.DoesNotExist:
            return Response({"status": False, "message": "Request not found"}, status=404)

        if update_request.status != "pending":
            return Response({"status": False, "message": "Already processed"}, status=400)

        product = update_request.product
        company = product.company if product else None   # 🔥 ADDED

        data = update_request.updated_data
        
        product_data = data.get("product_data", {})
        
        ###########################################
        # 🔥 normalize JSON fields
        json_fields = ["specifications", "variants", "variant_attributes"]

        for field in json_fields:
            value = product_data.get(field)

            if not value:
                continue
            
            # string → decode
            if isinstance(value, str):
                try:
                    value = json.loads(value)
                except:
                    pass
                
            # list containing JSON strings
            if isinstance(value, list):
                cleaned = []

                for item in value:
                    if isinstance(item, str):
                        try:
                            cleaned.append(json.loads(item))
                        except:
                            cleaned.append(item)
                    else:
                        cleaned.append(item)

                value = cleaned

            product_data[field] = value
            ###########################################

        # serializer = ProductSerializer(product, data=data.get("product_data", {}), partial=True)   # 🔁 MODIFIED
        serializer = ProductSerializer(product, data=product_data, partial=True)

        if serializer.is_valid():
            product = serializer.save()

            # --------------------------
            # FILE APPLY (same)
            # --------------------------
            if data.get("thumbnail"):
                product.thumbnail_s3_key = data["thumbnail"]
                product.save()

            for img in data.get("images", []):
                ProductImage.objects.create(product=product, image_s3_key=img)

            if data.get("delete_images"):
                ProductImage.objects.filter(
                    id__in=data["delete_images"], product=product
                ).delete()

            for vid in data.get("videos", []):
                ProductVideo.objects.create(product=product, video_s3_key=vid)

            if data.get("delete_videos"):
                ProductVideo.objects.filter(
                    id__in=data["delete_videos"], product=product
                ).delete()

            # --------------------------
            # STATUS UPDATE
            # --------------------------
            update_request.status = "approved"
            update_request.save()

            # --------------------------
            # 📧 EMAIL (NEW 🔥)
            # --------------------------
            try:
                email = None   # 🔥 ADDED

                if company:   # 🔥 ADDED
                    if company.email:
                        email = company.email
                    elif company.user and company.user.email:
                        email = company.user.email

                if email:
                    send_mail(   # 🔥 ADDED
                        subject="Product Update Request Approved 🎉",
                        message=f"""
Hello {company.name if company else "User"},

Your update request for product "{product.name}" has been APPROVED.

The changes are now live on the platform.

Thanks,
Admin Team
""",
                        from_email=settings.EMAIL_HOST_USER,
                        recipient_list=[email],
                        fail_silently=False
                    )

            except Exception as e:
                print("Email Error:", str(e))   # 🔥 ADDED

            return Response({
                "status": True,
                "message": "Approved, product updated & email sent"   # 🔁 MODIFIED
            })

        return Response({
            "status": False,
            "errors": serializer.errors
        })


class RejectProductUpdateAPIView(APIView):

    def post(self, request):

        request_id = request.data.get("request_id")
        reason = request.data.get("reason", "")

        # --------------------------
        # VALIDATION
        # --------------------------
        if not request_id:
            return Response({
                "status": False,
                "message": "request_id is required"
            }, status=400)

        try:
            # 🔥 OPTIMIZED QUERY
            update_request = ProductUpdateRequest.objects.select_related(
                "product__company", "product"
            ).get(id=request_id)

        except ProductUpdateRequest.DoesNotExist:
            return Response({
                "status": False,
                "message": "Request not found"
            }, status=404)

        if update_request.status != "pending":
            return Response({
                "status": False,
                "message": "Request already processed"
            }, status=400)

        # --------------------------
        # 🔴 MARK AS REJECTED
        # --------------------------
        update_request.status = "rejected"

        if reason and hasattr(update_request, "admin_comment"):
            update_request.admin_comment = reason

        update_request.save()

        # --------------------------
        # 📦 FETCH PRODUCT + COMPANY (FIXED)
        # --------------------------
        product = update_request.product
        company = product.company if product and product.company else None

        product_name = product.name if product else "Unknown Product"
        company_name = company.name if company else "Unknown Company"

        # --------------------------
        # 📧 EMAIL SENDING
        # --------------------------
        try:
            email = None

            if company:
                if company.email:
                    email = company.email
                elif company.user and company.user.email:
                    email = company.user.email

            if email:
                subject = "Product Update Request Rejected"

                message = f"""
Hello {company_name},

Your update request for the product "{product_name}" has been rejected.

Reason:
{reason if reason else "No reason provided"}

Please review and submit again.

Thanks,
Admin Team
"""

                send_mail(
                    subject,
                    message,
                    settings.EMAIL_HOST_USER,
                    [email],
                    fail_silently=False
                )
            else:
                print("No email found for company")

        except Exception as e:
            print("Email Error:", str(e))

        # --------------------------
        # 🧹 CLEANUP FILES (S3)
        # --------------------------
        try:
            data = update_request.updated_data or {}

            for img in data.get("images", []):
                delete_s3_file(img)

            for vid in data.get("videos", []):
                delete_s3_file(vid)

            if data.get("thumbnail"):
                delete_s3_file(data["thumbnail"])

        except Exception as e:
            print("Cleanup Error:", str(e))

        # --------------------------
        # RESPONSE
        # --------------------------
        return Response({
            "status": True,
            "message": "Update request rejected successfully",
            "data": {
                "request_id": request_id,
                "product_name": product_name,
                "company_name": company_name
            }
        })


class ProductUpdateRequestListAPIView(APIView):

    def post(self, request):
        # --------------------------
        # GET FILTERS FROM BODY
        # --------------------------
        status_filter = request.data.get("status")   # pending / approved / rejected
        product_id = request.data.get("product_id")
        page = request.data.get("page", 1)
        page_size = request.data.get("page_size", 10)
        queryset = ProductUpdateRequest.objects.select_related(
            "product", "requested_by"
        ).order_by("-created_at")
        # --------------------------
        # APPLY FILTERS
        # --------------------------
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        if product_id:
            queryset = queryset.filter(product_id=product_id)
        # --------------------------
        # PAGINATION
        # --------------------------
        paginator = PageNumberPagination()
        paginator.page_size = page_size
        result_page = paginator.paginate_queryset(queryset, request)
        data = []
        for obj in result_page:
            data.append({
                "request_id": obj.id,
                "status": obj.status,
                "created_at": obj.created_at,
                # USER INFO
                "requested_by": {
                    "id": obj.requested_by.id,
                    "name": getattr(obj.requested_by, "name", None),
                    "email": getattr(obj.requested_by, "email", None),
                },
                # PRODUCT INFO
                "product": {
                    "id": obj.product.id,
                    "name": obj.product.name,
                    "price": obj.product.price,
                    "thumbnail": obj.product.thumbnail_s3_key,
                },
                # 🔥 OPTIONAL: show updated data only if needed
                "updated_data": obj.updated_data if request.data.get("full") else None
            })
        return paginator.get_paginated_response({
            "status": True,
            "count": queryset.count(),
            "results": data
        })
        
        
from product.models import (
    ProductUpdateRequest,
    Product,
    Category,
    SubCategory,
    Brand,
    Unit
)
from company.models import Company


class UserProductUpdateRequestListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        requests = ProductUpdateRequest.objects.filter(
            requested_by=request.user
        ).select_related(
            "product",
            "requested_by"
        ).order_by('-created_at')

        data = []

        for obj in requests:

            updated_data = obj.updated_data or {}
            product_data = updated_data.get("product_data", {})

            # IDs चे names मिळवा
            unit_name = Unit.objects.filter(
                pk=product_data.get("unit")
            ).values_list("name", flat=True).first()

            brand_name = Brand.objects.filter(
                pk=product_data.get("brand")
            ).values_list("name", flat=True).first()

            category_name = Category.objects.filter(
                pk=product_data.get("category")
            ).values_list("name", flat=True).first()

            subcategory_name = SubCategory.objects.filter(
                pk=product_data.get("subcategory")
            ).values_list("name", flat=True).first()

            company_name = Company.objects.filter(
                pk=product_data.get("company")
            ).values_list("name", flat=True).first()

            product_name = Product.objects.filter(
                pk=product_data.get("product_id")
            ).values_list("name", flat=True).first()

            # IDs replace करा
            product_data["unit"] = unit_name
            product_data["brand"] = brand_name
            product_data["category"] = category_name
            product_data["subcategory"] = subcategory_name
            product_data["company"] = company_name
            product_data["product_id"] = product_name

            updated_data["product_data"] = product_data

            data.append({
                "request_id": obj.id,
                "status": obj.status,
                "created_at": obj.created_at,
                "product": {
                    "id": obj.product.id,
                    "name": obj.product.name,
                    "price": obj.product.price,
                    "thumbnail": obj.product.thumbnail_s3_key
                },
                "updated_data": updated_data
            })

        return Response({
            "status": True,
            "count": len(data),
            "data": data
        }, status=200)

class ProductListAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user

        products = Product.objects.filter(
            company__user=user,   # ✅ FIX HERE
            status='approved',
            is_active=True
        ).order_by('-id')

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "count": products.count(),
            "data": serializer.data
        })
        
        
class ProductListPendingAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        user = request.user

        products = Product.objects.filter(
            company__user=user,   # ✅ FIX HERE
            status='pending',
            is_active=True
        ).order_by('-id')

        serializer = ProductSerializer(products, many=True)

        return Response({
            "status": True,
            "count": products.count(),
            "data": serializer.data
        })



# class LatestApprovedProductAPIViewAuth(APIView):

#     authentication_classes = [JWTAuthentication]
#     permission_classes = [IsAuthenticated]

#     def post(self, request):

#         user = request.user

#         """
#         Fetch latest 5 approved and active products
#         """
#         products = Product.objects.filter(
#             company__user=user,
#             is_active=True,
#             status='approved'   # ✅ only approved products
#         ).order_by('-created_at')[:5]  # latest 5

#         serializer = LatestProductSerializer(products, many=True)

#         return Response({
#             "status": True,
#             "message": "Latest approved products fetched successfully",
#             "data": serializer.data
#         }, status=status.HTTP_200_OK)        
        

class LatestApprovedProductAPIView(APIView):

    def post(self, request):

        """
        Fetch latest 5 approved and active products
        """
        products = Product.objects.filter(
            is_active=True,
            status='approved'   # ✅ only approved products
        ).order_by('-created_at')[:5]  # latest 5

        serializer = LatestProductSerializer(products, many=True)

        return Response({
            "status": True,
            "message": "Latest approved products fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)        