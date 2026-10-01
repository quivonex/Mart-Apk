from django.core.management.base import BaseCommand
from django.utils import timezone
from product.models import Product

class Command(BaseCommand):
    help = 'Soft delete expired products (make inactive)'

    def handle(self, *args, **kwargs):
        today = timezone.now().date()

        expired_products = Product.objects.filter(
            expiry_date__lt=today,
            is_active=True
        )

        count = expired_products.update(is_active=False)

        self.stdout.write(self.style.SUCCESS(f"{count} products marked as inactive"))