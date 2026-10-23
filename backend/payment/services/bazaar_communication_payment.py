
# payments/services/bazaar_communication_payment.py

import uuid
from decimal import Decimal, ROUND_HALF_UP

import razorpay

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from rest_framework.exceptions import ValidationError

from olx.models import (
    BazaarCommunicationPlan,
    BazaarCommunicationSubscription,
)

from olx.bazaar_comm_services.communication_subscription import (
    activate_paid_subscription,
)

from payment.models import BazaarCommunicationPayment


class BazaarCommunicationPaymentService:
    """
    Razorpay service for Bazaar communication subscriptions.

    Does not modify or reuse the existing seller/listing payment flow.
    """

    @staticmethod
    def get_client():
        key_id = getattr(settings, "RAZORPAY_KEY_ID", None)
        key_secret = getattr(settings, "RAZORPAY_KEY_SECRET", None)

        if not key_id or not key_secret:
            raise ValidationError({
                "detail": "Razorpay credentials are not configured."
            })

        return razorpay.Client(
            auth=(key_id, key_secret)
        )

    @staticmethod
    def amount_to_paise(amount):
        amount = Decimal(str(amount))

        return int(
            (amount * Decimal("100")).quantize(
                Decimal("1"),
                rounding=ROUND_HALF_UP,
            )
        )

    @classmethod
    def create_order(cls, *, user, plan):
        """
        Create a Razorpay order and persist a pending subscription.

        `plan` must be an active BazaarCommunicationPlan instance.
        """
        if not plan or not plan.is_active:
            raise ValidationError({
                "plan_id": "The selected plan is unavailable."
            })

        if plan.price <= 0:
            raise ValidationError({
                "plan_id": "A paid order is not required for this plan."
            })

        client = cls.get_client()
        amount_paise = cls.amount_to_paise(plan.price)

        receipt = f"bc_{uuid.uuid4().hex[:24]}"

        try:
            order = client.order.create(
                data={
                    "amount": amount_paise,
                    "currency": plan.currency.upper(),
                    "receipt": receipt,
                    "notes": {
                        "user_id": str(user.pk),
                        "plan_id": str(plan.pk),
                        "purpose": "bazaar_communication_subscription",
                    },
                }
            )
        except Exception as exc:
            raise ValidationError({
                "detail": "Unable to create the Razorpay order."
            }) from exc

        # Capture the plan's entitlements now. Payment verification
        # activates this subscription later.
        with transaction.atomic():
            subscription = BazaarCommunicationSubscription.objects.create(
                user=user,
                plan=plan,
                starts_at=None,
                expires_at=None,
                status=BazaarCommunicationSubscription.Status.PENDING,
                price_paid=plan.price,
                currency=plan.currency.upper(),
                chat_limit_snapshot=plan.chat_limit,
                chat_unlimited_snapshot=plan.chat_unlimited,
                chat_limit_period_snapshot=plan.chat_limit_period,
                enquiry_limit_snapshot=plan.enquiry_limit,
                enquiry_unlimited_snapshot=plan.enquiry_unlimited,
                enquiry_limit_period_snapshot=plan.enquiry_limit_period,
                duration_days_snapshot=plan.duration_days,
                is_active=True,
            )

            payment = BazaarCommunicationPayment.objects.create(
                user=user,
                plan=plan,
                subscription=subscription,
                razorpay_order_id=order["id"],
                amount=plan.price,
                currency=plan.currency.upper(),
                status=BazaarCommunicationPayment.Status.CREATED,
                is_active=True,
            )

        return {
            "payment": payment,
            "subscription": subscription,
            "razorpay_order": order,
            "key_id": settings.RAZORPAY_KEY_ID,
        }

    @classmethod
    def verify_payment(
        cls,
        *,
        user,
        razorpay_order_id,
        razorpay_payment_id,
        razorpay_signature,
    ):
        """
        Verify a Razorpay payment and activate its pending subscription.

        Repeated verification of an already-paid order is idempotent.
        """
        payment = (
            BazaarCommunicationPayment.objects
            .filter(
                user=user,
                razorpay_order_id=razorpay_order_id,
            )
            .select_related("plan", "subscription")
            .first()
        )

        if payment is None:
            raise ValidationError({
                "razorpay_order_id": "Payment order was not found."
            })

        if payment.status == BazaarCommunicationPayment.Status.PAID:
            if payment.razorpay_payment_id != razorpay_payment_id:
                raise ValidationError({
                    "razorpay_payment_id": (
                        "This order was verified with another payment ID."
                    )
                })

            return {
                "payment": payment,
                "subscription": payment.subscription,
                "already_verified": True,
            }

        if payment.status != BazaarCommunicationPayment.Status.CREATED:
            raise ValidationError({
                "detail": "This payment cannot be verified in its current state."
            })

        client = cls.get_client()

        # Verify the HMAC signature using the saved order ID.
        try:
            client.utility.verify_payment_signature({
                "razorpay_order_id": razorpay_order_id,
                "razorpay_payment_id": razorpay_payment_id,
                "razorpay_signature": razorpay_signature,
            })
        except Exception as exc:
            raise ValidationError({
                "razorpay_signature": "Payment signature verification failed."
            }) from exc

        # Independently fetch the payment from Razorpay. A valid signature
        # alone is not a substitute for checking payment state and amount.
        try:
            remote_payment = client.payment.fetch(
                razorpay_payment_id
            )
        except Exception as exc:
            raise ValidationError({
                "detail": "Unable to retrieve payment details from Razorpay."
            }) from exc

        if remote_payment.get("order_id") != payment.razorpay_order_id:
            raise ValidationError({
                "detail": "Payment does not belong to this order."
            })

        expected_amount = cls.amount_to_paise(payment.amount)
        actual_amount = remote_payment.get("amount")

        if actual_amount != expected_amount:
            raise ValidationError({
                "detail": "The payment amount does not match the order."
            })

        if (
            str(remote_payment.get("currency", "")).upper()
            != payment.currency.upper()
        ):
            raise ValidationError({
                "detail": "The payment currency does not match the order."
            })

        if remote_payment.get("status") != "captured":
            failure_message = (
                "Payment has not been captured by Razorpay."
            )

            with transaction.atomic():
                locked_payment = (
                    BazaarCommunicationPayment.objects
                    .select_for_update()
                    .filter(pk=payment.pk)
                    .first()
                )

                if (
                    locked_payment
                    and locked_payment.status
                    == BazaarCommunicationPayment.Status.CREATED
                ):
                    locked_payment.status = (
                        BazaarCommunicationPayment.Status.FAILED
                    )
                    locked_payment.failure_reason = failure_message
                    locked_payment.save(
                        update_fields=[
                            "status",
                            "failure_reason",
                            "updated_at",
                        ]
                    )

                    if locked_payment.subscription_id:
                        BazaarCommunicationSubscription.objects.filter(
                            pk=locked_payment.subscription_id,
                            status=BazaarCommunicationSubscription.Status.PENDING,
                        ).update(
                            status=BazaarCommunicationSubscription.Status.FAILED
                        )

            raise ValidationError({
                "detail": failure_message
            })

        # Lock the local record to protect against concurrent verification.
        with transaction.atomic():
            locked_payment = (
                BazaarCommunicationPayment.objects
                .select_for_update()
                .select_related("plan", "subscription")
                .get(pk=payment.pk)
            )

            if locked_payment.status == BazaarCommunicationPayment.Status.PAID:
                if (
                    locked_payment.razorpay_payment_id
                    != razorpay_payment_id
                ):
                    raise ValidationError({
                        "detail": "Order has already been paid with another payment."
                    })

                return {
                    "payment": locked_payment,
                    "subscription": locked_payment.subscription,
                    "already_verified": True,
                }

            if (
                locked_payment.status
                != BazaarCommunicationPayment.Status.CREATED
            ):
                raise ValidationError({
                    "detail": "Payment is no longer awaiting verification."
                })

            if (
                locked_payment.razorpay_payment_id
                and locked_payment.razorpay_payment_id
                != razorpay_payment_id
            ):
                raise ValidationError({
                    "detail": "A different payment ID is already associated with this order."
                })

            locked_payment.razorpay_payment_id = razorpay_payment_id
            locked_payment.razorpay_signature = razorpay_signature
            locked_payment.status = BazaarCommunicationPayment.Status.PAID
            locked_payment.paid_at = timezone.now()
            locked_payment.failure_reason = ""

            locked_payment.save(
                update_fields=[
                    "razorpay_payment_id",
                    "razorpay_signature",
                    "status",
                    "paid_at",
                    "failure_reason",
                    "updated_at",
                ]
            )

            subscription = activate_paid_subscription(
                locked_payment
            )

            return {
                "payment": locked_payment,
                "subscription": subscription,
                "already_verified": False,
            }
