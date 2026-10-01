from decimal import Decimal

from django.db import transaction
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from agreement.models import AgreementProduct
from .models import ShipOrder
from commission.models import (
    CompanyWallet,
    WalletTransaction,
)


class ShiprocketDeliveryWebhookAPIView(APIView):

    permission_classes = [AllowAny]

    @transaction.atomic
    def post(self, request):

        # ==================================================
        # 1. Request Data
        # ==================================================

        order_number = request.data.get("order_number")

        # ==================================================
        # 2. Validation
        # ==================================================

        if not order_number:
            return Response(
                {
                    "success": False,
                    "message": "order_number is required"
                },
                status=400
            )

        # ==================================================
        # 3. Get Order
        # ==================================================

        order = (
            ShipOrder.objects
            .select_related(
                "company",
                "product"
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
                status=404
            )

        # ==================================================
        # 4. Check Already Commissioned
        # ==================================================

        already_credited = WalletTransaction.objects.filter(
            order=order,
            transaction_type="CREDIT"
        ).exists()

        if already_credited:

            if order.status != "DELIVERED":
                order.status = "DELIVERED"
                order.save(
                    update_fields=[
                        "status",
                        "updated_at"
                    ]
                )

            return Response({
                "success": True,
                "message": "Order already delivered and commission already credited.",
                "order_number": order.order_number
            })

        # ==================================================
        # 5. Mark Order as DELIVERED
        # ==================================================

        order.status = "DELIVERED"

        order.save(
            update_fields=[
                "status",
                "updated_at"
            ]
        )

        # ==================================================
        # 6. Find Agreement Product
        # ==================================================

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

        if not agreement_product:

            return Response({
                "success": True,
                "message": (
                    "Order delivered successfully, "
                    "but no active agreement found for this product."
                ),
                "order_number": order.order_number,
                "commission": "0.00"
            })

        # ==================================================
        # 7. Commission Percentage
        # ==================================================

        percentage = (
            agreement_product.profit_percentage
            or Decimal("0.00")
        )

        if percentage <= 0:

            return Response({
                "success": True,
                "message": (
                    "Order delivered, "
                    "but commission percentage is 0."
                ),
                "order_number": order.order_number,
                "commission": "0.00"
            })

        # ==================================================
        # 8. Sale Amount
        # ==================================================

        final_price = (
            order.product.final_price
            or Decimal("0.00")
        )

        sale_amount = (
            final_price * order.quantity
        )

        # ==================================================
        # 9. Calculate Commission
        # ==================================================

        commission_amount = (
            sale_amount * percentage / Decimal("100")
        ).quantize(Decimal("0.01"))

        # ==================================================
        # 10. Get / Create Company Wallet
        # ==================================================

        wallet, created = CompanyWallet.objects.get_or_create(
            company=order.company
        )

        # ==================================================
        # 11. Credit Wallet
        # ==================================================

        wallet.balance += commission_amount

        wallet.save(
            update_fields=[
                "balance",
                "updated_at"
            ]
        )

        # ==================================================
        # 12. Wallet Transaction
        # ==================================================

        WalletTransaction.objects.create(
            wallet=wallet,
            order=order,
            product=order.product,
            transaction_type="CREDIT",
            amount=commission_amount,
            commission_percentage=percentage,
            description=(
                f"Commission for delivered order "
                f"{order.order_number}"
            )
        )

        # ==================================================
        # 13. Response
        # ==================================================

        return Response({
            "success": True,
            "message": (
                "Order delivered and commission "
                "credited successfully."
            ),

            "order_number": order.order_number,

            "company": order.company.name,

            "product": order.product.name,

            "quantity": order.quantity,

            "product_price": final_price,

            "sale_amount": sale_amount,

            "commission_percentage": percentage,

            "commission_amount": commission_amount,

            "wallet_balance": wallet.balance
        })