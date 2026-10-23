from datetime import datetime, time, timedelta

from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from olx.models import (
    BazaarCommunicationPlan,
    BazaarCommunicationSettings,
    BazaarCommunicationSubscription,
    BazaarCommunicationUsage,
)

from .communication_subscription import (
    get_active_communication_subscriptions,
)

class BazaarCommunicationUsageService:

    @staticmethod
    def get_settings():
        settings_obj = (
            BazaarCommunicationSettings.objects
            .filter(is_active=True)
            .order_by("-updated_at", "-id")
            .first()
        )
        if settings_obj is None:
            settings_obj = BazaarCommunicationSettings.objects.create(
                is_active=True
            )
        return settings_obj

    @staticmethod
    def _calendar_period(period, now):
        """
        Return the current calendar period as timezone-aware boundaries.
        Weekly periods begin on Monday.
        """
        local_now = timezone.localtime(now)
        local_date = local_now.date()

        if period == "daily":
            start_date = local_date
            end_date = start_date + timedelta(days=1)
        elif period == "weekly":
            start_date = local_date - timedelta(
                days=local_date.weekday()
            )
            end_date = start_date + timedelta(days=7)
        elif period == "monthly":
            start_date = local_date.replace(day=1)
            if start_date.month == 12:
                end_date = start_date.replace(
                    year=start_date.year + 1,
                    month=1,
                )
            else:
                end_date = start_date.replace(
                    month=start_date.month + 1
                )
        else:
            raise ValidationError({
                "period": "Unsupported usage period."
            })

        tz = timezone.get_current_timezone()

        return (
            timezone.make_aware(
                datetime.combine(start_date, time.min),
                tz,
            ),
            timezone.make_aware(
                datetime.combine(end_date, time.min),
                tz,
            ),
        )

    @classmethod
    def _free_period(cls, feature, settings_obj, now):
        period = (
            settings_obj.free_chat_period
            if feature == BazaarCommunicationUsage.Feature.CHAT
            else settings_obj.free_enquiry_period
        )
        return cls._calendar_period(period, now)

    @classmethod
    def _paid_period(cls, subscription, feature, now):
        if feature == BazaarCommunicationUsage.Feature.CHAT:
            period = subscription.chat_limit_period_snapshot
        else:
            period = subscription.enquiry_limit_period_snapshot

        if period == BazaarCommunicationPlan.LimitPeriod.SUBSCRIPTION:
            start = subscription.starts_at
            end = subscription.expires_at
        else:
            calendar_start, calendar_end = cls._calendar_period(
                period,
                now,
            )
            start = max(calendar_start, subscription.starts_at)
            end = min(calendar_end, subscription.expires_at)

        return start, end

    @staticmethod
    def _get_usage_record(
        *,
        user,
        subscription,
        feature,
        period_start,
        period_end,
    ):
        """
        Call while the user row is locked inside transaction.atomic().
        This serializes consumption for the same user.
        """
        record = (
            BazaarCommunicationUsage.objects
            .filter(
                user=user,
                subscription=subscription,
                feature=feature,
                period_start=period_start,
                period_end=period_end,
                is_active=True,
            )
            .first()
        )
        if record:
            return record
        return BazaarCommunicationUsage.objects.create(
            user=user,
            subscription=subscription,
            feature=feature,
            period_start=period_start,
            period_end=period_end,
            used_count=0,
            is_active=True,
        )

    @staticmethod
    def _paid_entitlement(subscription, feature):
        if feature == BazaarCommunicationUsage.Feature.CHAT:
            return (
                subscription.chat_limit_snapshot,
                subscription.chat_unlimited_snapshot,
            )
        return (
            subscription.enquiry_limit_snapshot,
            subscription.enquiry_unlimited_snapshot,
        )

    @classmethod
    def _consume_free(
        cls,
        *,
        user,
        feature,
        settings_obj,
        now,
    ):
        if feature == BazaarCommunicationUsage.Feature.CHAT:
            limit = settings_obj.free_chat_limit
        else:
            limit = settings_obj.free_enquiry_limit

        period_start, period_end = cls._free_period(
            feature,
            settings_obj,
            now,
        )
        usage = cls._get_usage_record(
            user=user,
            subscription=None,
            feature=feature,
            period_start=period_start,
            period_end=period_end,
        )
        remaining = max(0, limit - usage.used_count)

        if remaining <= 0:
            return {
                "allowed": False,
                "source": "free",
                "limit": limit,
                "used": usage.used_count,
                "remaining": 0,
                "usage_id": usage.id,
            }

        usage.used_count += 1
        usage.save(update_fields=["used_count", "updated_at"])

        return {
            "allowed": True,
            "source": "free",
            "limit": limit,
            "used": usage.used_count,
            "remaining": max(0, limit - usage.used_count),
            "usage_id": usage.id,
        }

    @classmethod
    def _consume_paid(cls, *, user, feature, now):
        subscriptions = get_active_communication_subscriptions(user)

        for subscription in subscriptions:
            limit, unlimited = cls._paid_entitlement(
                subscription,
                feature,
            )

            if unlimited:
                return {
                    "allowed": True,
                    "source": "subscription",
                    "subscription_id": subscription.id,
                    "unlimited": True,
                    "remaining": None,
                }

            # A zero limit means this subscription provides no allowance
            # for the selected feature.
            if limit <= 0:
                continue

            period_start, period_end = cls._paid_period(
                subscription,
                feature,
                now,
            )
            usage = cls._get_usage_record(
                user=user,
                subscription=subscription,
                feature=feature,
                period_start=period_start,
                period_end=period_end,
            )
            remaining = max(0, limit - usage.used_count)

            if remaining <= 0:
                continue

            usage.used_count += 1
            usage.save(update_fields=["used_count", "updated_at"])

            return {
                "allowed": True,
                "source": "subscription",
                "subscription_id": subscription.id,
                "limit": limit,
                "used": usage.used_count,
                "remaining": max(0, limit - usage.used_count),
                "usage_id": usage.id,
            }

        return {
            "allowed": False,
            "source": "subscription",
            "remaining": 0,
        }

    @classmethod
    @transaction.atomic
    def consume(cls, *, user, feature):
        """
        Check access and consume one unit.

        feature must be "chat" or "enquiry".

        Modes:
        - free: unlimited free access
        - free_with_limit: free allowance only
        - subscription_required: paid entitlement only
        - mixed: free allowance first, then paid entitlements
        """
        if feature not in {
            BazaarCommunicationUsage.Feature.CHAT,
            BazaarCommunicationUsage.Feature.ENQUIRY,
        }:
            raise ValidationError({
                "feature": "Feature must be 'chat' or 'enquiry'."
            })

        # Serialize concurrent usage operations for this user.
        user_model = get_user_model()
        locked_user = (
            user_model.objects
            .select_for_update()
            .get(pk=user.pk)
        )
        settings_obj = cls.get_settings()
        now = timezone.now()
        mode = (
            settings_obj.chat_mode
            if feature == BazaarCommunicationUsage.Feature.CHAT
            else settings_obj.enquiry_mode
        )

        if mode == BazaarCommunicationSettings.AccessMode.FREE:
            return {
                "allowed": True,
                "source": "free",
                "unlimited": True,
                "remaining": None,
            }

        if mode == BazaarCommunicationSettings.AccessMode.FREE_WITH_LIMIT:
            result = cls._consume_free(
                user=locked_user,
                feature=feature,
                settings_obj=settings_obj,
                now=now,
            )
            if not result["allowed"]:
                raise ValidationError({
                    "detail": "Your free usage allowance is exhausted.",
                    "usage": result,
                })
            return result

        if mode == BazaarCommunicationSettings.AccessMode.SUBSCRIPTION_REQUIRED:
            result = cls._consume_paid(
                user=locked_user,
                feature=feature,
                now=now,
            )
            if not result["allowed"]:
                raise ValidationError({
                    "detail": (
                        "An active subscription with remaining "
                        "allowance is required."
                    ),
                    "usage": result,
                })
            return result

        if mode == BazaarCommunicationSettings.AccessMode.MIXED:
            free_result = cls._consume_free(
                user=locked_user,
                feature=feature,
                settings_obj=settings_obj,
                now=now,
            )
            if free_result["allowed"]:
                return free_result

            paid_result = cls._consume_paid(
                user=locked_user,
                feature=feature,
                now=now,
            )
            if paid_result["allowed"]:
                return paid_result

            raise ValidationError({
                "detail": (
                    "Your free allowance and paid subscription "
                    "allowances are exhausted."
                ),
                "free_usage": free_result,
                "paid_usage": paid_result,
            })

        raise ValidationError({
            "detail": "Unsupported communication access mode."
        })

    @classmethod
    def get_status(cls, *, user, feature):
        """
        Read-only usage overview for the usage API.
        Does not consume usage.
        """
        if feature not in {
            BazaarCommunicationUsage.Feature.CHAT,
            BazaarCommunicationUsage.Feature.ENQUIRY,
        }:
            raise ValidationError({
                "feature": "Feature must be 'chat' or 'enquiry'."
            })

        settings_obj = cls.get_settings()
        now = timezone.now()
        mode = (
            settings_obj.chat_mode
            if feature == BazaarCommunicationUsage.Feature.CHAT
            else settings_obj.enquiry_mode
        )

        if mode == BazaarCommunicationSettings.AccessMode.FREE:
            return {
                "feature": feature,
                "mode": mode,
                "allowed": True,
                "source": "free",
                "unlimited": True,
                "remaining": None,
            }

        free_limit = (
            settings_obj.free_chat_limit
            if feature == BazaarCommunicationUsage.Feature.CHAT
            else settings_obj.free_enquiry_limit
        )
        free_start, free_end = cls._free_period(
            feature,
            settings_obj,
            now,
        )
        free_usage = (
            BazaarCommunicationUsage.objects.filter(
                user=user,
                subscription__isnull=True,
                feature=feature,
                period_start=free_start,
                period_end=free_end,
                is_active=True,
            )
            .first()
        )
        free_used = free_usage.used_count if free_usage else 0
        free_remaining = max(0, free_limit - free_used)

        if mode in {
            BazaarCommunicationSettings.AccessMode.FREE_WITH_LIMIT,
            BazaarCommunicationSettings.AccessMode.MIXED,
        } and free_remaining > 0:
            return {
                "feature": feature,
                "mode": mode,
                "allowed": True,
                "source": "free",
                "limit": free_limit,
                "used": free_used,
                "remaining": free_remaining,
                "period_start": free_start,
                "period_end": free_end,
            }

        if mode == BazaarCommunicationSettings.AccessMode.FREE_WITH_LIMIT:
            return {
                "feature": feature,
                "mode": mode,
                "allowed": False,
                "source": "free",
                "limit": free_limit,
                "used": free_used,
                "remaining": 0,
            }

        if mode == BazaarCommunicationSettings.AccessMode.MIXED:
            paid = cls._get_paid_status(user=user, feature=feature, now=now)
            return {
                "feature": feature,
                "mode": mode,
                **paid,
            }

        if mode == BazaarCommunicationSettings.AccessMode.SUBSCRIPTION_REQUIRED:
            paid = cls._get_paid_status(user=user, feature=feature, now=now)
            return {
                "feature": feature,
                "mode": mode,
                **paid,
            }

        raise ValidationError({
            "detail": "Unsupported communication access mode."
        })

    @classmethod
    def _get_paid_status(cls, *, user, feature, now):
        for subscription in get_active_communication_subscriptions(user):
            limit, unlimited = cls._paid_entitlement(
                subscription,
                feature,
            )

            if unlimited:
                return {
                    "allowed": True,
                    "source": "subscription",
                    "subscription_id": subscription.id,
                    "unlimited": True,
                    "remaining": None,
                }

            if limit <= 0:
                continue

            period_start, period_end = cls._paid_period(
                subscription,
                feature,
                now,
            )
            usage = (
                BazaarCommunicationUsage.objects.filter(
                    user=user,
                    subscription=subscription,
                    feature=feature,
                    period_start=period_start,
                    period_end=period_end,
                    is_active=True,
                )
                .first()
            )
            used = usage.used_count if usage else 0
            remaining = max(0, limit - used)

            if remaining > 0:
                return {
                    "allowed": True,
                    "source": "subscription",
                    "subscription_id": subscription.id,
                    "limit": limit,
                    "used": used,
                    "remaining": remaining,
                    "period_start": period_start,
                    "period_end": period_end,
                }

        return {
            "allowed": False,
            "source": "subscription",
            "remaining": 0,
        }