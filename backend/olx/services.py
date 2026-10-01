from datetime import timedelta

from django.utils import timezone

from .models import (
    BazaarSettings,
    BazaarListing,
    BazaarPayment,
    BazaarRenewal,
)


# ============================================================
# GET BAZAAR SETTINGS
# ============================================================

def get_bazaar_settings():

    settings = BazaarSettings.objects.filter(
        is_active=True
    ).first()

    if not settings:

        settings = BazaarSettings.objects.create(
            first_listing_free=True,
            free_listing_days=15,
            payment_required_after_expiry=True
        )

    return settings


# ============================================================
# GET USER LISTING COUNT
# ============================================================

def get_user_listing_count(user):

    return BazaarListing.objects.filter(
        user=user
    ).count()


# ============================================================
# ACTIVATE FIRST FREE LISTING
# ============================================================

def activate_first_listing(listing):

    config = get_bazaar_settings()

    if not config.first_listing_free:

        return False

    now = timezone.now()

    listing.is_first_listing = True

    listing.free_period_days = (
        config.free_listing_days
    )

    listing.active_from = now

    listing.expires_at = (
        now +
        timedelta(
            days=config.free_listing_days
        )
    )

    listing.status = "active"

    listing.save(
        update_fields=[
            "is_first_listing",
            "free_period_days",
            "active_from",
            "expires_at",
            "status",
            "updated_at",
        ]
    )

    return True


# ============================================================
# ACTIVATE / RENEW PAID LISTING
# ============================================================

def activate_paid_listing(
    listing,
    payment
):

    now = timezone.now()

    old_expiry = listing.expires_at

    # --------------------------------------------------------
    # IF CURRENT LISTING IS STILL ACTIVE
    # EXTEND FROM EXISTING EXPIRY
    # --------------------------------------------------------

    if (
        old_expiry and
        old_expiry > now
    ):

        start = old_expiry

    else:

        start = now

    # --------------------------------------------------------
    # PLAN DURATION
    # --------------------------------------------------------

    duration_days = payment.plan.duration_days

    new_expiry = (
        start +
        timedelta(
            days=duration_days
        )
    )

    # --------------------------------------------------------
    # LISTING UPDATE
    # --------------------------------------------------------

    listing.active_from = (
        listing.active_from or now
    )

    listing.expires_at = new_expiry

    listing.status = "active"

    # Paid listing is no longer considered first listing
    listing.is_first_listing = False

    listing.free_period_days = 0

    listing.save(
        update_fields=[
            "active_from",
            "expires_at",
            "status",
            "is_first_listing",
            "free_period_days",
            "updated_at",
        ]
    )

    # --------------------------------------------------------
    # CREATE RENEWAL RECORD
    # --------------------------------------------------------

    BazaarRenewal.objects.create(
        listing=listing,
        payment=payment,
        old_expiry=old_expiry or now,
        new_expiry=new_expiry
    )

    return listing