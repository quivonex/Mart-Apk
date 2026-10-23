from django.db import models


class Businessman(models.Model):
    company_name = models.CharField(max_length=500, db_index=True)
    ai_business_category = models.CharField(max_length=255, blank=True, null=True)
    contact_person = models.CharField(max_length=255, blank=True, null=True)
    gender = models.CharField(max_length=20, blank=True, null=True)
    mobile = models.CharField(max_length=20, blank=True, null=True, db_index=True)
    phone_validation_status = models.CharField(max_length=50, blank=True, null=True)
    email = models.EmailField(max_length=255, blank=True, null=True, db_index=True)
    email_type = models.CharField(max_length=100, blank=True, null=True)
    email_score = models.IntegerField(blank=True, null=True)
    original_catalog_url = models.TextField(blank=True, null=True)
    catalog_link_status = models.CharField(max_length=50, blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True, db_index=True)
    state = models.CharField(max_length=100, blank=True, null=True)
    pincode = models.CharField(max_length=20, blank=True, null=True)
    full_address = models.TextField(blank=True, null=True)
    seller_type = models.CharField(max_length=50, blank=True, null=True)

    # Email tracking
    email_sent = models.BooleanField(default=False, db_index=True)
    email_sent_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'businessman'
        ordering = ['-id']
        indexes = [
            models.Index(fields=['city', 'ai_business_category']),
        ]

    def __str__(self):
        return self.company_name