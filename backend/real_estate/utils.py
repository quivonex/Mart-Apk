from django.utils import timezone


def check_property_subscription(property_obj):
    """
    Returns True when property subscription is required.
    Returns False when property is currently accessible.
    """

    # Admin-created properties are always free
    if property_obj.source == "admin":
        return False

    # Paid subscription is active
    if property_obj.subscription_active:
        return False

    # Free period is still active
    if (
        property_obj.free_expiry_date
        and timezone.now() < property_obj.free_expiry_date
    ):
        return False

    # No free period OR free period expired
    return True