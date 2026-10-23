from rest_framework import serializers
from olx.models import BazaarCommunicationPlan
from .models import BazaarCommunicationPayment


class BazaarCommunicationCreateOrderSerializer(
    serializers.Serializer
):
    """
    Validates the plan selected for a Razorpay order.

    The authenticated user must come from request.user in the view,
    never from client-supplied user_id.
    """

    plan_id = serializers.IntegerField(min_value=1)

    def validate_plan_id(self, value):
        plan = BazaarCommunicationPlan.objects.filter(
            id=value,
            is_active=True,
        ).first()

        if plan is None:
            raise serializers.ValidationError(
                "The selected communication plan does not exist "
                "or is inactive."
            )

        if plan.price <= 0:
            raise serializers.ValidationError(
                "This plan does not require a paid checkout."
            )

        self.context["plan"] = plan
        return value


class BazaarCommunicationVerifyPaymentSerializer(
    serializers.Serializer
):
    """
    Accepts Razorpay's payment identifiers for server-side verification.

    This serializer does not itself verify the payment or activate
    a subscription. That must happen in the payment service/view.
    """

    razorpay_order_id = serializers.CharField(
        max_length=100,
        trim_whitespace=True,
    )
    razorpay_payment_id = serializers.CharField(
        max_length=100,
        trim_whitespace=True,
    )
    razorpay_signature = serializers.CharField(
        max_length=255,
        trim_whitespace=True,
        write_only=True,
    )

    def validate(self, attrs):
        if not attrs["razorpay_order_id"].startswith("order_"):
            raise serializers.ValidationError({
                "razorpay_order_id": (
                    "Invalid Razorpay order ID format."
                )
            })

        if not attrs["razorpay_payment_id"].startswith("pay_"):
            raise serializers.ValidationError({
                "razorpay_payment_id": (
                    "Invalid Razorpay payment ID format."
                )
            })

        return attrs


class BazaarCommunicationPaymentSerializer(
    serializers.ModelSerializer
):
    """
    Read-only payment representation for payment history APIs.
    """

    plan_name = serializers.CharField(
        source="plan.name",
        read_only=True,
    )
    subscription_id = serializers.IntegerField(
        read_only=True,
        allow_null=True,
    )

    class Meta:
        model = BazaarCommunicationPayment
        fields = [
            "id",
            "plan",
            "plan_name",
            "subscription_id",
            "razorpay_order_id",
            "razorpay_payment_id",
            "amount",
            "currency",
            "status",
            "failure_reason",
            "paid_at",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields