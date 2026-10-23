from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from olx.models import BazaarCommunicationSubscription

def get_active_communication_subscriptions(user):
    """
    Return valid subscriptions, newest first.

    The usage service consumes the newest subscription first.
    """
    now = timezone.now()

    return BazaarCommunicationSubscription.objects.filter(
        user=user,
        status=BazaarCommunicationSubscription.Status.ACTIVE,
        is_active=True,
        starts_at__lte=now,
        expires_at__gt=now,
    ).order_by("-created_at", "-id")

@transaction.atomic
def activate_paid_subscription(payment):
    """
    Activate the pending subscription linked to a verified payment.

    Prefer a subscription created when the Razorpay order was created,
    because its entitlement snapshots preserve the original plan.
    """
    subscription = None

    if payment.subscription_id:
        subscription = (
            BazaarCommunicationSubscription.objects
            .select_for_update()
            .filter(id=payment.subscription_id, user=payment.user)
            .first()
        )

    if subscription and (
        subscription.status
        == BazaarCommunicationSubscription.Status.ACTIVE
        and subscription.starts_at
        and subscription.expires_at
        and subscription.expires_at > timezone.now()
    ):
        return subscription

    now = timezone.now()

    if subscription is None:
        # Fallback for a payment without a pre-created subscription.
        plan = payment.plan
        subscription = BazaarCommunicationSubscription(
            user=payment.user,
            plan=plan,
            price_paid=payment.amount,
            currency=payment.currency,
            chat_limit_snapshot=plan.chat_limit,
            chat_unlimited_snapshot=plan.chat_unlimited,
            chat_limit_period_snapshot=plan.chat_limit_period,
            enquiry_limit_snapshot=plan.enquiry_limit,
            enquiry_unlimited_snapshot=plan.enquiry_unlimited,
            enquiry_limit_period_snapshot=plan.enquiry_limit_period,
        )

    subscription.starts_at = now
    subscription.expires_at = now + timedelta(
        days=subscription.plan.duration_days
    )
    subscription.status = BazaarCommunicationSubscription.Status.ACTIVE
    subscription.is_active = True
    subscription.save()
    payment.subscription = subscription
    payment.save(update_fields=["subscription", "updated_at"])

    return subscription