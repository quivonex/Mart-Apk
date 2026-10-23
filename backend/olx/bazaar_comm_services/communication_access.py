from rest_framework.exceptions import ValidationError

from olx.models import BazaarCommunicationUsage
from .communication_usage import BazaarCommunicationUsageService

class BazaarCommunicationAccessService:

    @staticmethod
    def validate_feature(feature):
        valid_features = {
            BazaarCommunicationUsage.Feature.CHAT,
            BazaarCommunicationUsage.Feature.ENQUIRY,
        }
        if feature not in valid_features:
            raise ValidationError({
                "feature": "Feature must be 'chat' or 'enquiry'."
            })

    @classmethod
    def get_status(cls, *, user, feature):
        cls.validate_feature(feature)
        return BazaarCommunicationUsageService.get_status(
            user=user,
            feature=feature,
        )

    @classmethod
    def consume(cls, *, user, feature):
        """
        Consume one allowance for a successful chat/enquiry action.

        Call this from inside the same outer transaction as the action
        being recorded, where possible, so a failed database operation
        does not leave usage consumed.
        """
        cls.validate_feature(feature)
        return BazaarCommunicationUsageService.consume(
            user=user,
            feature=feature,
        )