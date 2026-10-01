from django.core.management.base import BaseCommand
from django.utils import timezone

from olx.models import BazaarListing


class Command(BaseCommand):

    help = "Expire old Bazaar listings"

    def handle(self, *args, **kwargs):

        now = timezone.now()

        count = BazaarListing.objects.filter(
            status="active",
            expires_at__lte=now
        ).update(
            status="expired"
        )

        self.stdout.write(
            self.style.SUCCESS(
                f"{count} listings expired."
            )
        )