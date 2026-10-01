from django.db import models # type: ignore

class Offer(models.Model):

    OFFER_TYPE = (
        ('percentage', 'Percentage Discount'),
        ('flat', 'Fixed Discount'),
    )

    title = models.CharField(max_length=255)
    description = models.TextField()
    offer_type = models.CharField(max_length=20, choices=OFFER_TYPE, null=True, blank=True)
    discount_value = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    products = models.ManyToManyField('product.Product', blank=True, related_name="offers")
    
    company = models.ForeignKey(
        'company.Company',
        on_delete=models.CASCADE,
        related_name="offers",
        null=True,
        blank=True
    )
    
    # NOTE: This field allows an offer to be associated with multiple branches, and a branch can have multiple offers.(Many-to-Many relationship)
    # NOTE: Not in Use currently, but can be used in the future to create branch-specific offers or promotions.
    branch = models.ManyToManyField(
        'branch.Branch',
        blank=True,
        related_name="offers"
    )

    def __str__(self):
        return self.title