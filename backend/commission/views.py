from decimal import Decimal

from django.db import transaction
from rest_framework.views import APIView
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from shiprocket.models import ShipOrder
from agreement.models import AgreementProduct, MarketingPartnerAgreement

from commission.models import (
    CompanyWallet,
    WalletTransaction,
    MarketingPartnerWallet,
    MarketingPartnerWalletTransaction,
)

from enquiry.models import (
    MarketingPartner,
    
)

from commission.models import (
    PlatformWallet,
    PlatformWalletTransaction,
)


class ShiprocketDeliveryWebhookAPIView(APIView):

    permission_classes = [AllowAny]

    @transaction.atomic
    def post(self, request):

        # ==========================================================
        # 1. GET ORDER NUMBER
        # ==========================================================

        order_number = request.data.get("order_number")

        if not order_number:
            return Response(
                {
                    "success": False,
                    "message": "order_number is required"
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # ==========================================================
        # 2. GET ORDER
        # ==========================================================

        order = (
            ShipOrder.objects
            .select_related(
                "company",
                "product",
                "user"
            )
            .filter(
                order_number=order_number
            )
            .first()
        )

        if not order:
            return Response(
                {
                    "success": False,
                    "message": "Order not found",
                    "order_number": order_number
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # ==========================================================
        # 3. MARK ORDER AS DELIVERED
        # ==========================================================

        if order.status != "DELIVERED":

            order.status = "DELIVERED"

            order.save(
                update_fields=[
                    "status",
                    "updated_at"
                ]
            )

        # ==========================================================
        # 4. SALE AMOUNT
        # ==========================================================

        final_price = (
            order.product.final_price
            or Decimal("0.00")
        )

        quantity = order.quantity or 1

        sale_amount = (
            final_price * quantity
        ).quantize(
            Decimal("0.01")
        )

        if sale_amount <= 0:

            return Response(
                {
                    "success": True,
                    "message": (
                        "Order delivered successfully, "
                        "but sale amount is zero."
                    ),
                    "order_number": order.order_number,
                    "sale_amount": "0.00"
                },
                status=status.HTTP_200_OK
            )

        # ==========================================================
        # RESPONSE DATA
        # ==========================================================

        response_data = {
            "success": True,
            "message": "Order delivered successfully.",

            "order_number": order.order_number,

            "product_id": order.product_id,
            "company_id": order.company_id,

            "quantity": quantity,
            "sale_amount": str(sale_amount),

            # ------------------------------------------------------
            # COMPANY
            # ------------------------------------------------------

            "company_amount": "0.00",

            # ------------------------------------------------------
            # QNX MART
            # ------------------------------------------------------

            "qnx_mart_gross_commission": "0.00",
            "qnx_mart_net_commission": "0.00",

            # ------------------------------------------------------
            # MARKETING PARTNER
            # ------------------------------------------------------

            "marketing_partner": None,
            "marketing_partner_commission": "0.00",
            "marketing_partner_percentage": "0.00",
            "marketing_partner_commission_type": None,
        }

        # ==========================================================
        # 5. FIND AGREEMENT PRODUCT
        # ==========================================================

        agreement_product = (
            AgreementProduct.objects
            .select_related("agreement")
            .filter(
                agreement__company=order.company,
                product=order.product,
                is_active=True
            )
            .first()
        )

        # ==========================================================
        # 6. QNX MART GROSS COMMISSION
        # ==========================================================

        qnx_mart_gross_commission = Decimal("0.00")
        company_amount = sale_amount

        if agreement_product:

            qnx_mart_percentage = (
                agreement_product.profit_percentage
                or Decimal("0.00")
            )

            # ------------------------------------------------------
            # SAFETY
            # ------------------------------------------------------

            if qnx_mart_percentage < 0:
                qnx_mart_percentage = Decimal("0.00")

            if qnx_mart_percentage > 100:
                qnx_mart_percentage = Decimal("100.00")

            # ------------------------------------------------------
            # QNX MART GROSS COMMISSION
            # ------------------------------------------------------

            qnx_mart_gross_commission = (
                sale_amount
                * qnx_mart_percentage
                / Decimal("100")
            ).quantize(
                Decimal("0.01")
            )

            # ------------------------------------------------------
            # COMPANY GETS SALE - QNX MART GROSS COMMISSION
            #
            # Example:
            # Sale = 10,000
            # QNX Mart = 20% = 2,000
            # Company = 8,000
            # ------------------------------------------------------

            company_amount = (
                sale_amount
                - qnx_mart_gross_commission
            ).quantize(
                Decimal("0.01")
            )

        # ==========================================================
        # 7. MARKETING PARTNER
        # ==========================================================

        marketing_partner = None
        partner_commission = Decimal("0.00")
        partner_percentage = Decimal("0.00")
        partner_commission_type = None

        # ----------------------------------------------------------
        # FIND PARTNER USING COMPANY REFERRAL CODE
        # ----------------------------------------------------------

        if (
            order.company
            and order.company.referral_code
        ):

            marketing_partner = (
                MarketingPartner.objects
                .filter(
                    referral_code=order.company.referral_code
                )
                .first()
            )

        # ==========================================================
        # 8. MARKETING PARTNER COMMISSION
        # ==========================================================

        if marketing_partner:

            response_data["marketing_partner"] = {
                "id": marketing_partner.id,
                "name": marketing_partner.full_name,
                "referral_code": marketing_partner.referral_code,
            }

            # ------------------------------------------------------
            # GET APPROVED PARTNER AGREEMENT
            # ------------------------------------------------------

            partner_agreement = (
                MarketingPartnerAgreement.objects
                .filter(
                    marketing_partner=marketing_partner,
                    status="approved"
                )
                .order_by("-created_at")
                .first()
            )

            if partner_agreement:

                # ==================================================
                # PARTNER PERSONALLY SOLD THE PRODUCT
                #
                # selling_commission_percentage
                # ==================================================

                if (
                    marketing_partner.user_id
                    and order.user_id
                    == marketing_partner.user_id
                ):

                    partner_percentage = (
                        partner_agreement
                        .selling_commission_percentage
                        or Decimal("0.00")
                    )

                    partner_commission_type = (
                        "SELLING_COMMISSION"
                    )

                # ==================================================
                # NORMAL CUSTOMER PURCHASE
                #
                # profit_share_percentage
                # ==================================================

                else:

                    partner_percentage = (
                        partner_agreement
                        .profit_share_percentage
                        or Decimal("0.00")
                    )

                    partner_commission_type = (
                        "PROFIT_SHARE"
                    )

                # --------------------------------------------------
                # SAFETY
                # --------------------------------------------------

                if partner_percentage < 0:
                    partner_percentage = Decimal("0.00")

                if partner_percentage > 100:
                    partner_percentage = Decimal("100.00")

                # ==================================================
                # IMPORTANT
                #
                # Partner commission is calculated FROM
                # QNX MART GROSS COMMISSION.
                #
                # NOT from sale_amount.
                #
                # Example:
                #
                # Sale = 10,000
                # QNX Mart gross = 2,000
                # Partner = 10%
                #
                # Partner = 2,000 × 10% = 200
                #
                # QNX Mart net = 2,000 - 200 = 1,800
                # ==================================================

                if qnx_mart_gross_commission > 0:

                    partner_commission = (
                        qnx_mart_gross_commission
                        * partner_percentage
                        / Decimal("100")
                    ).quantize(
                        Decimal("0.01")
                    )

                else:

                    partner_commission = Decimal("0.00")

        # ==========================================================
        # 9. QNX MART NET COMMISSION
        # ==========================================================

        qnx_mart_net_commission = (
            qnx_mart_gross_commission
            - partner_commission
        ).quantize(
            Decimal("0.01")
        )

        # Safety
        if qnx_mart_net_commission < 0:
            qnx_mart_net_commission = Decimal("0.00")

        # ==========================================================
        # UPDATE RESPONSE
        # ==========================================================

        response_data["company_amount"] = str(
            company_amount
        )

        response_data["qnx_mart_gross_commission"] = str(
            qnx_mart_gross_commission
        )

        response_data["qnx_mart_net_commission"] = str(
            qnx_mart_net_commission
        )

        response_data["marketing_partner_commission"] = str(
            partner_commission
        )

        response_data["marketing_partner_percentage"] = str(
            partner_percentage
        )

        response_data["marketing_partner_commission_type"] = (
            partner_commission_type
        )

        # ==========================================================
        # 10. COMPANY WALLET
        # ==========================================================

        if company_amount > 0:

            company_wallet, created = (
                CompanyWallet.objects
                .select_for_update()
                .get_or_create(
                    company=order.company
                )
            )

            # ------------------------------------------------------
            # DUPLICATE CHECK
            # ------------------------------------------------------

            company_transaction_exists = (
                WalletTransaction.objects
                .filter(
                    order=order,
                    transaction_type="CREDIT"
                )
                .exists()
            )

            if not company_transaction_exists:

                company_wallet.balance = (
                    company_wallet.balance
                    + company_amount
                )

                company_wallet.save(
                    update_fields=[
                        "balance",
                        "updated_at"
                    ]
                )

                WalletTransaction.objects.create(
                    wallet=company_wallet,
                    order=order,
                    product=order.product,

                    transaction_type="CREDIT",

                    amount=company_amount,

                    commission_percentage=(
                        agreement_product.profit_percentage
                        if agreement_product
                        else Decimal("0.00")
                    ),

                    description=(
                        f"Company payout for delivered order "
                        f"{order.order_number}. "
                        f"Sale ₹{sale_amount} - "
                        f"QNX Mart gross commission "
                        f"₹{qnx_mart_gross_commission}"
                    )
                )

        # ==========================================================
        # 11. MARKETING PARTNER WALLET
        # ==========================================================

        if (
            marketing_partner
            and partner_commission > 0
        ):

            partner_wallet, created = (
                MarketingPartnerWallet.objects
                .select_for_update()
                .get_or_create(
                    marketing_partner=marketing_partner
                )
            )

            # ------------------------------------------------------
            # DUPLICATE CHECK
            # ------------------------------------------------------

            partner_transaction_exists = (
                MarketingPartnerWalletTransaction.objects
                .filter(
                    order=order,
                    transaction_type="CREDIT"
                )
                .exists()
            )

            if not partner_transaction_exists:

                partner_wallet.balance = (
                    partner_wallet.balance
                    + partner_commission
                )

                partner_wallet.save(
                    update_fields=[
                        "balance",
                        "updated_at"
                    ]
                )

                MarketingPartnerWalletTransaction.objects.create(
                    wallet=partner_wallet,

                    company=order.company,

                    order=order,

                    product=order.product,

                    transaction_type="CREDIT",

                    amount=partner_commission,

                    commission_percentage=partner_percentage,

                    # IMPORTANT:
                    # Partner commission is based on
                    # QNX Mart gross commission.
                    base_amount=qnx_mart_gross_commission,

                    commission_type=partner_commission_type,

                    description=(
                        f"{partner_commission_type} for "
                        f"delivered order "
                        f"{order.order_number}. "
                        f"Partner commission ₹"
                        f"{partner_commission} deducted "
                        f"from QNX Mart commission."
                    )
                )

        # ==========================================================
        # 12. QNX MART PLATFORM WALLET
        # ==========================================================

        if qnx_mart_net_commission > 0:

            # ------------------------------------------------------
            # Get/Create Platform Wallet
            #
            # If your PlatformWallet is OneToOne/single wallet,
            # get_or_create(id=1) is fine.
            # ------------------------------------------------------

            platform_wallet, created = (
                PlatformWallet.objects
                .select_for_update()
                .get_or_create(
                    id=1
                )
            )

            # ------------------------------------------------------
            # DUPLICATE CHECK
            # ------------------------------------------------------

            platform_transaction_exists = (
                PlatformWalletTransaction.objects
                .filter(
                    order=order,
                    transaction_type="CREDIT"
                )
                .exists()
            )

            if not platform_transaction_exists:

                platform_wallet.balance = (
                    platform_wallet.balance
                    + qnx_mart_net_commission
                )

                platform_wallet.save(
                    update_fields=[
                        "balance",
                        "updated_at"
                    ]
                )

                PlatformWalletTransaction.objects.create(
                    wallet=platform_wallet,

                    order=order,

                    product=order.product,

                    transaction_type="CREDIT",

                    amount=qnx_mart_net_commission,

                    # This is the original QNX Mart
                    # commission percentage.
                    commission_percentage=(
                        agreement_product.profit_percentage
                        if agreement_product
                        else Decimal("0.00")
                    ),

                    sale_amount=sale_amount,

                    description=(
                        f"QNX Mart NET commission for "
                        f"delivered order "
                        f"{order.order_number}. "

                        f"Gross commission ₹"
                        f"{qnx_mart_gross_commission} - "

                        f"Marketing Partner commission ₹"
                        f"{partner_commission} = "

                        f"Net ₹"
                        f"{qnx_mart_net_commission}"
                    )
                )

        # ==========================================================
        # 13. NO AGREEMENT PRODUCT
        # ==========================================================

        if not agreement_product:

            response_data["message"] = (
                "Order delivered successfully. "
                "No active AgreementProduct found. "
                "Company and QNX Mart product commission "
                "was not processed."
            )

        # ==========================================================
        # 14. FINAL RESPONSE
        # ==========================================================

        return Response(
            response_data,
            status=status.HTTP_200_OK
        )