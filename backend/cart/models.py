from django.db import models # type: ignore
from accounts.models import User  # तुझा custom User model
from product.models import Product  # तुझा Product model

class CartItem(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='cart_items')
    product = models.ForeignKey(Product, on_delete=models.CASCADE)
    quantity = models.PositiveIntegerField(default=1)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'product')  # same product user मध्ये duplicate होणार नाही

    def __str__(self):
        return f"{self.user.username} - {self.product.name} ({self.quantity})"