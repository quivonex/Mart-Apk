import email

from django.core.mail import send_mail # type: ignore
from django.conf import settings # type: ignore

from rest_framework.views import APIView # type: ignore
from rest_framework.response import Response, Serializer # type: ignore
from rest_framework import status # type: ignore
from .models import Enquiry, MarketingPartner
from .serializers import CompanyProductEnquirySerializer, EnquirySerializer, LatestEnquirySerializer, MarketingPartnerSerializer, ProductEnquirySerializer, UenquirySerializer
import json
from .serializers import UenquirySerializer, BankDetailsSerializer
from .models import Uenquiry
from rest_framework.permissions import IsAuthenticated # type: ignore
from rest_framework_simplejwt.authentication import JWTAuthentication # type: ignore
from .models import Enquiry, MarketingPartner, ProductEnquiry, Uenquiry, BankDetails
from agreement.models import MarketingPartnerAgreement


from accounts.models import User, EmailOTP

from accounts.utils import (
    generate_otp,
    send_otp_email
)

from admin_profile.models import admin_Role

from django.utils import timezone # type: ignore



class EnquiryCreateAPIView(APIView):

    def post(self, request):

        data = request.data.copy()

        # JSON string → python list
        if data.get("contacts"):
            try:
                data["contacts"] = json.loads(data["contacts"])
            except:
                pass

        if data.get("emails"):
            try:
                data["emails"] = json.loads(data["emails"])
            except:
                pass

        # products handle
        products = data.get("products", None)

        serializer = EnquirySerializer(data=data)

        if serializer.is_valid():

            enquiry = serializer.save()

            # ManyToMany save
            if products:
                try:
                    product_list = json.loads(products)
                    enquiry.products.set(product_list)
                except:
                    enquiry.products.set(products)

            return Response({
                "status": True,
                "message": "Enquiry created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "message": "Validation error",
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    


class EnquiryListAPIView(APIView):

    def post(self, request):

        enquiries = Enquiry.objects.all().order_by("-id")

        serializer = EnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Enquiry list fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
    
class EnquirycountListAPIView(APIView):

    def post(self, request):

        status_param = request.data.get('status')

        enquiries = Enquiry.objects.all().order_by("-id")

        if status_param:
            enquiries = enquiries.filter(status=status_param)

        serializer = EnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "count": enquiries.count(),
           
        })


class LatestEnquiryListAPIView(APIView):

    def post(self, request):

        enquiries = Enquiry.objects.all().order_by('-created_at')[:5]

        serializer = LatestEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Latest enquiries fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)




class UenquiryCreateAPIView(APIView):

    def post(self, request):
        serializer = UenquirySerializer(data=request.data)

        if serializer.is_valid():
            serializer.save()
            return Response({
                "status": True,
                "message": "Enquiry submitted successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    

class UenquiryListAPIView(APIView):

    def post(self, request):
        enquiries = Uenquiry.objects.all().order_by('-created_at')
        serializer = UenquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Enquiry list fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)  
        
        

class SendToCompanyAPIView(APIView):

    def post(self, request):
        enquiry_id = request.data.get('id')

        try:
            enquiry = ProductEnquiry.objects.get(id=enquiry_id)

            # ✅ status update to sent
            enquiry.is_sent_to_company = True
            enquiry.save()

            return Response({
                "message": "Enquiry sent to company successfully",
                "status": True
            }, status=status.HTTP_200_OK)

        except ProductEnquiry.DoesNotExist:
            return Response({
                "message": "Enquiry not found",
                "status": False
            }, status=status.HTTP_404_NOT_FOUND)  
            
class EnquiryApproveRejectAPIView(APIView):

    def post(self, request):
        enquiry_id = request.data.get('id')
        action = request.data.get('action')  # approve / reject

        try:
            enquiry = ProductEnquiry.objects.get(id=enquiry_id)

            if action == "approve":
                enquiry.status = "approved"

            elif action == "reject":
                enquiry.status = "rejected"

            else:
                return Response({
                    "message": "Invalid action. Use approve or reject"
                }, status=status.HTTP_400_BAD_REQUEST)

            enquiry.save()

            return Response({
                "message": f"Enquiry {action}d successfully",
                "status": True
            }, status=status.HTTP_200_OK)

        except ProductEnquiry.DoesNotExist:
            return Response({
                "message": "Enquiry not found",
                "status": False
            }, status=status.HTTP_404_NOT_FOUND)                    

class ApprovedEnquiryList(APIView):

    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(status="approved").order_by('-created_at')
        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
class ApprovedEnquiryListAPIView(APIView):

    permission_classes = [IsAuthenticated]

    def post(self, request):

        enquiries = ProductEnquiry.objects.filter(
            # is_sent_to_company=True,
            status='approved'
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(
            enquiries,
            many=True
        )

        return Response({
            "status": True,
            "message": "Approved enquiries fetched successfully",
            "data": serializer.data
        })
                
    
class SentToCompanyListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        company_id = request.data.get("company_id")

        enquiries = ProductEnquiry.objects.filter(
            is_sent_to_company=True,
            status='pending',
            product__company_id=company_id
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
class LatestUEnquiryListAPIView(APIView):

    def post(self, request):

        enquiries = Uenquiry.objects.order_by('-created_at')[:5]

        serializer = UenquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Latest 5 enquiries fetched successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK) 
    

from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from decimal import Decimal
from product.models import Product

from django.shortcuts import get_object_or_404
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from decimal import Decimal

class CreateProductEnquiryAPIView(APIView):
    def post(self, request):
        # 🔥 URL मधून product आणि ref_code घ्या (पर्यायी)
        product_slug = request.GET.get('product')
        ref_code = request.GET.get('ref_code')
        
        # Debugging साठी print करा
        print(f"Product Slug from URL: {product_slug}")
        print(f"Ref Code from URL: {ref_code}")
        print(f"All GET params: {dict(request.GET)}")
        
        # Body मधून data घ्या
        data = request.data.copy()
        
        # 🔥 Product ID किंवा Slug शोधा (प्रथम body मध्ये, नंतर URL मध्ये)
        product_id = data.get('product')
        
        # जर body मध्ये product नसेल आणि URL मध्ये slug असेल
        if not product_id and product_slug:
            try:
                product = Product.objects.get(slug=product_slug)
                data["product"] = product.id
            except Product.DoesNotExist:
                return Response({
                    "status": False,
                    "message": "Product not found with given slug."
                }, status=status.HTTP_404_NOT_FOUND)
        
        # जर body मध्ये product id असेल
        elif product_id:
            try:
                product = Product.objects.get(id=int(product_id))
            except (ValueError, Product.DoesNotExist):
                return Response({
                    "status": False,
                    "message": "Product not found with given ID."
                }, status=status.HTTP_404_NOT_FOUND)
        
        # जर कुठेही product नसेल
        else:
            return Response({
                "status": False,
                "message": "Product ID or slug is required."
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Product price at enquiry time
        price = product.final_price if product.final_price else product.price
        quantity = int(data.get("quantity", 1))
        
        # Save enquiry-time price
        data["unit_price"] = str(price)
        data["total_amount"] = str(Decimal(price) * quantity)
        
        # 🔥 enquiry_referral_code set करा (जर असेल तरच)
        if ref_code:
            data["enquiry_referral_code"] = ref_code
            print(f"Setting enquiry_referral_code to: {ref_code}")
        else:
            print("No ref_code found, skipping...")
        
        # Product ID data मध्ये आहे याची खात्री करा
        data["product"] = product.id
        
        serializer = ProductEnquirySerializer(data=data)
        
        if serializer.is_valid():
            enquiry = serializer.save(
                user=request.user if request.user.is_authenticated else None,
                product=product
            )
            
            return Response({
                "status": True,
                "message": "Enquiry submitted successfully.",
                "data": ProductEnquirySerializer(enquiry).data
            }, status=status.HTTP_201_CREATED)
        
        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class CreateBankDetailsAPIView(APIView):

    def post(self, request):

        marketing_partner_id = request.data.get(
            "marketing_partner"
        )

        # =========================================
        # 🔥 CHECK MARKETING PARTNER
        # =========================================

        try:
            marketing_partner = MarketingPartner.objects.get(
                id=marketing_partner_id
            )

        except MarketingPartner.DoesNotExist:
            return Response({
                "status": False,
                "message": "Marketing partner not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # =========================================
        # 🔥 ONE TO ONE CHECK
        # =========================================

        if BankDetails.objects.filter(
            marketing_partner=marketing_partner
        ).exists():

            return Response({
                "status": False,
                "message": "Bank details already added"
            }, status=status.HTTP_400_BAD_REQUEST)

        # =========================================
        # 🔥 SERIALIZER
        # =========================================

        serializer = BankDetailsSerializer(
            data=request.data
        )

        if serializer.is_valid():

            serializer.save(
                marketing_partner=marketing_partner
            )

            return Response({
                "status": True,
                "message": "Bank details created successfully",
                "data": serializer.data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
        


class UpdateBankDetailsAPIView(APIView):

    def post(self, request):

        bank_details_id = request.data.get("id")

        if not bank_details_id:
            return Response({
                "status": False,
                "message": "Bank Details ID is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            bank_details = BankDetails.objects.get(id=bank_details_id)

        except BankDetails.DoesNotExist:
            return Response({
                "status": False,
                "message": "Bank Details not found"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = BankDetailsSerializer(
            bank_details,
            data=request.data,
            partial=True
        )

        if serializer.is_valid():
            serializer.save()

            return Response({
                "status": True,
                "message": "Bank details updated successfully",
                "data": serializer.data
            }, status=status.HTTP_200_OK)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)     

class CompanyProductEnquiryListAPIView(APIView):

    def post(self, request):

        enquiries = ProductEnquiry.objects.filter(
            status='pending'
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Pending enquiries fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)

# class CompanyProductEnquiryListAPIView(APIView):

#     def post(self, request):

#         enquiries = ProductEnquiry.objects.filter(
#             status='pending'
#         ).order_by('-created_at')

#         serializer = ProductEnquirySerializer(enquiries, many=True)

#         return Response({
#             "status": True,
#             "message": "Pending enquiries fetched successfully",
#             "count": enquiries.count(),
#             "data": serializer.data
#         }, status=status.HTTP_200_OK)
from datetime import datetime
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

class CompanyProductEnquiryListAPIView(APIView):

    def post(self, request):

        from_date = request.data.get("from_date")
        to_date = request.data.get("to_date")

        enquiries = ProductEnquiry.objects.filter(status='pending')

        # Date Filter
        if from_date and to_date:
            try:
                from_date = datetime.strptime(from_date, "%Y-%m-%d").date()
                to_date = datetime.strptime(to_date, "%Y-%m-%d").date()

                enquiries = enquiries.filter(
                    created_at__date__range=[from_date, to_date]
                )
            except ValueError:
                return Response({
                    "status": False,
                    "message": "Invalid date format. Use YYYY-MM-DD"
                }, status=status.HTTP_400_BAD_REQUEST)

        elif from_date:
            try:
                from_date = datetime.strptime(from_date, "%Y-%m-%d").date()

                enquiries = enquiries.filter(
                    created_at__date__gte=from_date
                )
            except ValueError:
                return Response({
                    "status": False,
                    "message": "Invalid from_date format. Use YYYY-MM-DD"
                }, status=status.HTTP_400_BAD_REQUEST)

        elif to_date:
            try:
                to_date = datetime.strptime(to_date, "%Y-%m-%d").date()

                enquiries = enquiries.filter(
                    created_at__date__lte=to_date
                )
            except ValueError:
                return Response({
                    "status": False,
                    "message": "Invalid to_date format. Use YYYY-MM-DD"
                }, status=status.HTTP_400_BAD_REQUEST)

        enquiries = enquiries.order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Pending enquiries fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
        
class MyProductEnquiryListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        enquiries = ProductEnquiry.objects.filter(
            user=request.user
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "My enquiries fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
                
class RecentCompanyEnquiriesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company = Company.objects.filter(user=request.user).first()

        if not company:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=status.HTTP_404_NOT_FOUND)

        enquiries = ProductEnquiry.objects.filter(
            product__company=company
        ).order_by('-created_at')[:5]

        serializer = LatestEnquirySerializer(enquiries, many=True)

        return Response({
            "status": True,
            "message": "Recent enquiries fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
class CompletedEnquiryListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        enquiries = Enquiry.objects.filter(is_completed=True).order_by('-id')
        serializer = EnquirySerializer(enquiries, many=True)
        return Response(
            {
                "status": True,
                "message": "Completed enquiries fetched successfully.",
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )        



import random
import string
from .models import MarketingPartner
from .serializers import MarketingPartnerSerializer
from accounts.models import User
from .s3_upload import upload_file_to_s3

class MarketingPartnerCreateAPIView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):
        data = request.data.copy()
        email = (
            data.get("email", "")
            .strip()
        )
        mobile = (
            data.get("mobile", "")
            .strip()
        )

        data["email"] = email
        data["mobile"] = mobile

        partner_email_exists = MarketingPartner.objects.filter(
            email__iexact=email
        ).exclude(
            status='rejected'
        ).exists()

        if partner_email_exists:
            return Response({
                "status": False,
                "message": "Marketing partner email already exists"
            }, status=status.HTTP_400_BAD_REQUEST)

        partner_mobile_exists = MarketingPartner.objects.filter(
            mobile=mobile
        ).exclude(
            status='rejected'
        ).exists()

        if partner_mobile_exists:
            return Response({
                "status": False,
                "message": "Mobile already exists"
            }, status=status.HTTP_400_BAD_REQUEST)

        if User.objects.filter(
            email__iexact=email
        ).exists():

            return Response({
                "status": False,
                "message": "Email already exists in users"
            }, status=status.HTTP_400_BAD_REQUEST)

        referred_by_code = data.get(
            "referred_by_code"
        )

        referred_by = None

        if referred_by_code:
            referred_by = MarketingPartner.objects.filter(
                referral_code=referred_by_code
            ).first()

        profile_image = request.FILES.get(
            "profile_image"
        )

        if profile_image:
            upload_response = upload_file_to_s3(
                profile_image,
                folder="marketing_partner/profile"
            )
            if not upload_response["status"]:
                return Response({
                    "status": False,
                    "message": upload_response["message"]
                }, status=status.HTTP_400_BAD_REQUEST)
            if "profile_image" in data:
                data.pop("profile_image")
            data["profile_image"] = upload_response[
                "file_url"
            ]

        serializer = MarketingPartnerSerializer(
            data=data
        )

        if serializer.is_valid():
            instance = serializer.save(
                referred_by=referred_by
            )
            frontend_url = (
                "https://qnxmartb2b.com"  # Replace with your actual frontend URL
            )
            if (
                instance.application_type
                == "marketing_partner"
            ):
                instance.referral_link = (
                    f"{frontend_url}/company_create"
                    f"?ref={instance.referral_code}"
                )
            else:
                instance.referral_link = (
                    f"{frontend_url}/marketing-partner-enquiry"
                    f"?ref={instance.referral_code}"
                )
            instance.save()

            return Response({
                "status": True,
                "message": "Application submitted successfully",
                "data": MarketingPartnerSerializer(
                    instance
                ).data
            }, status=status.HTTP_201_CREATED)

        return Response({
            "status": False,
            "errors": serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)



class CompleteMarketingPartnerRegistrationAPIView(APIView):

    def post(self, request):

        email = request.data.get("email")
        username = request.data.get("username")
        password = request.data.get("password")

        # 🔹 REQUIRED
        if not all([email, username, password]):
            return Response({
                "status": False,
                "message": "All fields required"
            }, status=400)

        # 🔹 USERNAME EXISTS
        if User.objects.filter(username__iexact=username).exists():
            return Response({
                "status": False,
                "message": "Username already exists"
            }, status=400)

        # 🔹 OTP VERIFIED CHECK
        otp_obj = EmailOTP.objects.filter(
            email=email,
            is_verified=True
        ).first()

        if not otp_obj:
            return Response({
                "status": False,
                "message": "OTP not verified"
            }, status=400)

        # 🔹 PARTNER
        partner = MarketingPartner.objects.filter(
            email__iexact=email
        ).first()

        if not partner:
            return Response({
                "status": False,
                "message": "Partner not found"
            }, status=404)

        # =====================================================
        # 🔹 AGREEMENT CHECK
        # =====================================================
        # agreement = Agreement.objects.filter(
        #     marketing_partner=partner,
        #     status="approved"
        # ).first()

        # if not agreement:
        #     return Response({
        #         "status": False,
        #         "message": "Agreement not found or not approved."
        #     }, status=400)

        # 🔹 ACCOUNT EXISTS
        if partner.user:
            return Response({
                "status": False,
                "message": "Account already created"
            }, status=400)

        # 🔹 ROLE
        role_name = request.data.get("role")

        role = admin_Role.objects.filter(
            role_name=role_name
        ).first()

        if not role:
            return Response({
                "status": False,
                "message": "Role not found"
            }, status=404)

        # 🔹 CREATE USER
        user = User.objects.create(
            username=username,
            email=partner.email,
            name=partner.full_name,
            phone_number=partner.mobile,
            role=role,
            is_email_verified=True
        )

        user.set_password(password)
        user.save()

        # 🔹 LINK USER
        partner.user = user
        partner.status = "approved"
        partner.otp_verified = True
        partner.save()
        
       
        # 🔹 SEND LOGIN CREDENTIALS EMAIL
        send_mail(
            subject="Marketing Partner Account Created",
            message=f"""
Hello {partner.full_name},

Your marketing partner account has been created successfully.

Login Credentials:

Username: {username}

Password: {password}

Email: {partner.email}

URL: https://qnxmartb2b.com/admin/

Please log in using the above credentials.
Then, click on the  link and complete the required Agreement details to receive your Referral Code and Referral Link, which you can use to refer new Marketing Partners.
Thanks,
QNX MART Team
""",
            from_email=settings.EMAIL_HOST_USER,
            recipient_list=[partner.email],
            fail_silently=False
        )

        # 🔹 DELETE OTP
        otp_obj.delete()

        return Response({
            "status": True,
            "message": "Account created successfully",
            "data": {
                "user_id": user.id,
                "partner_id": partner.id,
            }
        }, status=201)

class RejectMarketingPartnerAPIView(APIView):

    def post(self, request):

        partner_id = request.data.get("partner_id")
        reason = request.data.get("reason", "")
        partner = MarketingPartner.objects.filter(
            id=partner_id
        ).first()

        if not partner:
            return Response({
                "status": False,
                "message": "Partner not found"
            }, status=404)

        # 🔹 Already rejected
        if partner.status == "rejected":
            return Response({
                "status": False,
                "message": "Partner already rejected"
            }, status=400)

        # 🔹 Update status
        partner.status = "rejected"
        partner.save()
        # 🔹 SEND REJECTION EMAIL
        send_mail(

            subject="Marketing Partner Application Rejected",

            message=f"""
Hello {partner.full_name},

We regret to inform you that your marketing partner application has been rejected.

Reason:
{reason}

For more details please contact support.

Thanks,
Quivonex Solutions
            """,

            from_email=settings.EMAIL_HOST_USER,

            recipient_list=[partner.email],

            fail_silently=False
        )

        return Response({
            "status": True,
            "message": "Partner rejected successfully"
        })


class MarketingHeadListAPIView(APIView):

    def post(self, request):

        heads = MarketingPartner.objects.filter(
            application_type='marketing_head'
        )
        serializer = MarketingPartnerSerializer(heads, many=True)
        return Response({
            "status": True,
            "message": "Marketing heads fetched successfully",
            "count": heads.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class MyMarketingProfileAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        partner = MarketingPartner.objects.filter(
            user=request.user
        ).first()

        if not partner:
            return Response({
                "status": False,
                "message": "Marketing profile not found"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = MarketingPartnerSerializer(partner)
        return Response({
            "status": True,
            "message": "Profile fetched successfully",
            "application_type": partner.application_type,
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class MyReferredMarketingPartnersAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 🔹 Logged in user's marketing profile
        marketing_head = MarketingPartner.objects.filter(
            user=request.user,
            application_type='marketing_head'
        ).first()

        if not marketing_head:
            return Response({
                "status": False,
                "message": "Marketing head profile not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # 🔹 Get referred partners
        partners = MarketingPartner.objects.filter(
            referred_by=marketing_head,
            application_type='marketing_partner'
        ).order_by('-id')

        serializer = MarketingPartnerSerializer(
            partners,
            many=True
        )

        return Response({
            "status": True,
            "marketing_head": marketing_head.full_name,
            "referral_code": marketing_head.referral_code,
            "count": partners.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class ReferredMarketingPartnersAPIView(APIView):

    def post(self, request):

        partner_id = request.data.get("partner_id")

        if not partner_id:
            return Response({
                "status": False,
                "message": "partner_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔹 Get marketing head
        marketing_head = MarketingPartner.objects.filter(
            id=partner_id,
            application_type='marketing_head'
        ).first()

        if not marketing_head:
            return Response({
                "status": False,
                "message": "Marketing head not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # 🔹 Get referred partners
        partners = MarketingPartner.objects.filter(
            referred_by=marketing_head,
            application_type='marketing_partner'
        ).order_by('-id')

        serializer = MarketingPartnerSerializer(
            partners,
            many=True
        )

        return Response({
            "status": True,
            "marketing_head": marketing_head.full_name,
            "referral_code": marketing_head.referral_code,
            "count": partners.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class MarketingPartnerListAPIView(APIView):

    def post(self, request):

        partners = MarketingPartner.objects.filter(
            application_type='marketing_partner'
        )

        serializer = MarketingPartnerSerializer(
            partners,
            many=True
        )

        return Response({
            "status": True,
            "message": "Marketing partners fetched successfully",
            "count": partners.count(),
            "data": serializer.data
        })    
        
class ApprovedMarketingPartnerListAPIView(APIView):

    def post(self, request):

        partners = MarketingPartner.objects.filter(
            status="approved"
        ).order_by("-created_at")

        serializer = MarketingPartnerSerializer(
            partners,
            many=True,
            context={"request": request}
        )

        return Response({
            "status": True,
            "message": "Approved marketing partners fetched successfully",
            "count": partners.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)

class ApprovedMarketingPartnerCountAPIView(APIView):

    def post(self, request):

        count = MarketingPartner.objects.filter(
            status="approved"
        ).count()

        return Response({
            "status": True,
            "message": "Approved marketing partners count fetched successfully",
            "count": count
        }, status=status.HTTP_200_OK)
        
                
from rest_framework.views import APIView # type: ignore
from rest_framework.response import Response # type: ignore
from rest_framework import status # type: ignore
from company.models import Company
from enquiry.models import MarketingPartner
from company.serializers import CompanySerializer


class MarketingPartnerCompaniesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 🔹 Logged in marketing partner
        partner = MarketingPartner.objects.filter(
            user=request.user
        ).first()

        if not partner:
            return Response({
                "status": False,
                "message": "Marketing partner profile not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # 🔹 Fetch companies
        companies = Company.objects.filter(
            referral_code=partner.referral_code
        ).order_by('-id')

        serializer = CompanySerializer(
            companies,
            many=True
        )

        return Response({
            "status": True,
            "marketing_partner": partner.full_name,
            "referral_code": partner.referral_code,
            "total_companies": companies.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)


class MarketingHeadCompaniesAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        # 🔹 Logged in marketing head
        marketing_head = MarketingPartner.objects.filter(
            user=request.user,
            application_type='marketing_head'
        ).first()

        if not marketing_head:
            return Response({
                "status": False,
                "message": "Marketing head profile not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # 🔹 Get all referred marketing partners
        partners = MarketingPartner.objects.filter(
            referred_by=marketing_head,
            application_type='marketing_partner'
        )

        final_data = []
        total_companies = 0

        # 🔹 Loop all partners
        for partner in partners:
            companies = Company.objects.filter(
                referral_code=partner.referral_code
            ).order_by('-id')
            total_companies += companies.count()
            company_serializer = CompanySerializer(
                companies,
                many=True
            )
            final_data.append({
                "partner_id": partner.id,
                "partner_name": partner.full_name,
                "partner_email": partner.email,
                "partner_mobile": partner.mobile,
                "partner_referral_code": partner.referral_code,
                "total_companies": companies.count(),
                "companies": company_serializer.data
            })

        return Response({
            "status": True,
            "marketing_head": marketing_head.full_name,
            "marketing_head_referral_code": marketing_head.referral_code,
            "total_partners": partners.count(),
            "total_companies": total_companies,
            "data": final_data
        }, status=status.HTTP_200_OK)


class PartnerCompaniesByIdAPIView(APIView):

    def post(self, request):

        partner_id = request.data.get("partner_id")

        if not partner_id:
            return Response({
                "status": False,
                "message": "partner_id is required"
            }, status=status.HTTP_400_BAD_REQUEST)

        # 🔹 Get partner
        partner = MarketingPartner.objects.filter(
            id=partner_id,
            application_type='marketing_partner'
        ).first()

        if not partner:
            return Response({
                "status": False,
                "message": "Marketing partner not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # 🔹 Fetch companies using referral code
        companies = Company.objects.filter(
            referral_code=partner.referral_code
        ).order_by('-id')

        serializer = CompanySerializer(
            companies,
            many=True
        )

        return Response({
            "status": True,
            "partner_id": partner.id,
            "partner_name": partner.full_name,
            "partner_referral_code": partner.referral_code,
            "total_companies": companies.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
        
        
class RetrieveBankDetailsAPIView(APIView):

    def post(self, request):

        marketing_partner_id = request.data.get(
            "marketing_partner"
        )

        # =========================================
        # 🔥 CHECK MARKETING PARTNER
        # =========================================

        try:
            marketing_partner = MarketingPartner.objects.get(
                id=marketing_partner_id
            )

        except MarketingPartner.DoesNotExist:
            return Response({
                "status": False,
                "message": "Marketing partner not found"
            }, status=status.HTTP_404_NOT_FOUND)

        # =========================================
        # 🔥 GET BANK DETAILS
        # =========================================

        try:
            bank_details = BankDetails.objects.get(
                marketing_partner=marketing_partner
            )

        except BankDetails.DoesNotExist:
            return Response({
                "status": False,
                "message": "Bank details not found"
            }, status=status.HTTP_404_NOT_FOUND)

        serializer = BankDetailsSerializer(
            bank_details
        )

        return Response({
            "status": True,
            "message": "Bank details retrieved successfully",
            "data": serializer.data
        }, status=status.HTTP_200_OK)        



class CompanyAdminProductEnquiryListAPIView(APIView):

    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        companies = Company.objects.filter(
            user=request.user
        )

        if not companies.exists():
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=status.HTTP_404_NOT_FOUND)

        enquiries = ProductEnquiry.objects.filter(
            product__company__in=companies,
            is_sent_to_company=True
        ).exclude(
            status='approved'
        ).order_by("-created_at")

        serializer = CompanyProductEnquirySerializer(
            enquiries,
            many=True
        )

        return Response({
            "status": True,
            "message": "Pending enquiries fetched successfully",
            "count": enquiries.count(),
            "data": serializer.data
        }, status=status.HTTP_200_OK)
# class SentProductEnquiryListAPIView(APIView):

#     permission_classes = [IsAuthenticated]

#     def post(self, request):

#         enquiries = ProductEnquiry.objects.filter(
#             is_sent_to_company=True
#         ).exclude(
#             status='approved'
#         ).order_by('-created_at')

#         serializer = CompanyProductEnquirySerializer(
#             enquiries,
#             many=True
#         )

#         return Response({
#             "status": True,
#             "data": serializer.data
#         })
class CompanyAdminLatestProductEnquiryListAPIView(APIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def post(self, request):

        company = Company.objects.filter(user=request.user).first()

        if not company:
            return Response({
                "status": False,
                "message": "Company not found"
            }, status=status.HTTP_404_NOT_FOUND)

        enquiries = ProductEnquiry.objects.filter(
            product__company=company,
            status="pending"
        ).order_by("-created_at")[:5]   # Latest 5 enquiries

        serializer = CompanyProductEnquirySerializer(
            enquiries,
            many=True
        )

        return Response({
            "status": True,
            "message": "Latest 5 pending enquiries fetched successfully",
            "count": len(serializer.data),
            "data": serializer.data
        }, status=status.HTTP_200_OK)        
        
class ProductEnquiryCompleteUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        enquiry_id = request.data.get("id")
        is_complete = request.data.get("is_complete")

        if enquiry_id is None:
            return Response(
                {
                    "status": "error",
                    "message": "Enquiry ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            enquiry = ProductEnquiry.objects.get(id=enquiry_id)
        except ProductEnquiry.DoesNotExist:
            return Response(
                {
                    "status": "error",
                    "message": "Enquiry not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        enquiry.is_complete = is_complete
        enquiry.save()

        return Response(
            {
                "status": "success",
                "message": "is_complete status updated successfully.",
                "data": {
                    "id": enquiry.id,
                    "is_complete": enquiry.is_complete
                }
            },
            status=status.HTTP_200_OK
        )     
                   
class CompletedProductEnquiryListAPIView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(
            is_complete=True
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(
            enquiries,
            many=True
        )

        return Response(
            {
                "status": "success",
                "message": "Completed enquiry list fetched successfully.",
                "total": enquiries.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
                   
class ProductEnquiryDispatchUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]   # आवश्यक असल्यास वापरा

    def post(self, request):
        enquiry_id = request.data.get("id")
        is_dispatched = request.data.get("is_dispatched")

        if enquiry_id is None:
            return Response(
                {
                    "status": "error",
                    "message": "Enquiry ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            enquiry = ProductEnquiry.objects.get(id=enquiry_id)
        except ProductEnquiry.DoesNotExist:
            return Response(
                {
                    "status": "error",
                    "message": "Product Enquiry not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        enquiry.is_dispatched = is_dispatched
        enquiry.save()

        return Response(
            {
                "status": "success",
                "message": "Dispatch status updated successfully.",
                "id": enquiry.id,
                "is_dispatched": enquiry.is_dispatched
            },
            status=status.HTTP_200_OK
        )    
        
class ProductEnquiryDispatchedRetrieveAPIView(APIView):
    permission_classes = [IsAuthenticated] 
    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(is_dispatched=True).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response(
            {
                "status": "success",
                "count": len(serializer.data),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )        
        
class ProductEnquiryDispatchedRetrieveAllAPIView(APIView):
    
    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(is_dispatched=True).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response(
            {
                "status": "success",
                "count": len(serializer.data),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )                
                       
class ProductEnquiryDeliveredUpdateAPIView(APIView):
    permission_classes = [IsAuthenticated]   # आवश्यक असल्यास वापरा

    def post(self, request):
        enquiry_id = request.data.get("id")
        is_delivered = request.data.get("is_delivered")

        if enquiry_id is None:
            return Response(
                {
                    "status": "error",
                    "message": "Enquiry ID is required."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            enquiry = ProductEnquiry.objects.get(id=enquiry_id)
        except ProductEnquiry.DoesNotExist:
            return Response(
                {
                    "status": "error",
                    "message": "Product Enquiry not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        enquiry.is_delivered = is_delivered
        enquiry.save()

        return Response(
            {
                "status": "success",
                "message": "Delivery status updated successfully.",
                "id": enquiry.id,
                "is_delivered": enquiry.is_delivered
            },
            status=status.HTTP_200_OK
        )      
class ProductEnquiryDeliveredListAPIView(APIView):

    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(
            is_delivered=True
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response(
            {
                "status": "success",
                "count": enquiries.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
        
class ProductEnquiryDeliveredListAllAPIView(APIView):

    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(
            is_delivered=True
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(enquiries, many=True)

        return Response(
            {
                "status": "success",
                "count": enquiries.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )      
        
                               
class CompletedProductEnquiryAllListAPIView(APIView):
   

    def post(self, request):
        enquiries = ProductEnquiry.objects.filter(
            is_complete=True
        ).order_by('-created_at')

        serializer = ProductEnquirySerializer(
            enquiries,
            many=True
        )

        return Response(
            {
                "status": "success",
                "message": "Completed enquiry list fetched successfully.",
                "total": enquiries.count(),
                "data": serializer.data
            },
            status=status.HTTP_200_OK
        )
                                      
                                      
                                      
class ProductEnquiryCountAPIView(APIView):

    def post(self, request):

        queryset = ProductEnquiry.objects.filter(status="approved")

        total_enquiries = queryset.count()
        paid_enquiries = queryset.filter(is_paid=True).count()
        unpaid_enquiries = queryset.filter(is_paid=False).count()

        return Response({
            "status": True,
            "data": {
                "total_enquiries": total_enquiries,
                "paid_enquiries": paid_enquiries,
                "unpaid_enquiries": unpaid_enquiries
            }
        }, status=status.HTTP_200_OK)
        
        
class CompanyWiseProductEnquiryCountAPIView(APIView):

    def post(self, request):
        company_id = request.data.get("company_id")

        if not company_id:
            return Response({
                "status": False,
                "message": "company_id is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            company = Company.objects.get(id=company_id)
        except Company.DoesNotExist:
            return Response({
                "status": False,
                "message": "Company not found."
            }, status=status.HTTP_404_NOT_FOUND)

        queryset = ProductEnquiry.objects.filter(
            product__company=company,
            status="approved"
        )

        total_enquiries = queryset.count()
        paid_enquiries = queryset.filter(is_paid=True).count()
        unpaid_enquiries = queryset.filter(is_paid=False).count()

        return Response({
            "status": True,
            "message": "Approved company enquiry counts fetched successfully.",
            "data": {
                "company_id": company.id,
                "company_name": company.name,
                "total_enquiries": total_enquiries,
                "paid_enquiries": paid_enquiries,
                "unpaid_enquiries": unpaid_enquiries
            }
        }, status=status.HTTP_200_OK)
        
class ProductEnquiryCompleteCountAPIView(APIView):

    def post(self, request):

        queryset = ProductEnquiry.objects.filter(status="approved")

        total_enquiries = queryset.count()
        complete_enquiries = queryset.filter(is_complete=True).count()
        incomplete_enquiries = queryset.filter(is_complete=False).count()

        return Response({
            "status": True,
            "data": {
                "total_enquiries": total_enquiries,
                "complete_enquiries": complete_enquiries,
                "incomplete_enquiries": incomplete_enquiries
            }
        }, status=status.HTTP_200_OK)
                
class CompanyWiseEnquiryCountAPIView(APIView):

    def post(self, request):
        company_id = request.data.get("company_id")

        if not company_id:
            return Response({
                "status": False,
                "message": "company_id is required."
            }, status=status.HTTP_400_BAD_REQUEST)

        try:
            company = Company.objects.get(id=company_id)
        except Company.DoesNotExist:
            return Response({
                "status": False,
                "message": "Company not found."
            }, status=status.HTTP_404_NOT_FOUND)

        queryset = ProductEnquiry.objects.filter(
            product__company=company,
            status="approved"
        )

        total_enquiries = queryset.count()
        complete_enquiries = queryset.filter(is_complete=True).count()
        incomplete_enquiries = queryset.filter(is_complete=False).count()

        return Response({
            "status": True,
            "data": {
                "company_id": company.id,
                "company_name": company.name,
                "total_enquiries": total_enquiries,
                "complete_enquiries": complete_enquiries,
                "incomplete_enquiries": incomplete_enquiries
            }
        }, status=status.HTTP_200_OK)