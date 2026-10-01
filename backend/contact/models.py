from django.db import models


class ContactUs(models.Model):


    id = models.AutoField(primary_key=True)

    name = models.CharField(max_length=150)
    phone = models.CharField(max_length=15)
    email = models.EmailField(blank=True, null=True)

    subject = models.CharField(max_length=50,)

    message = models.TextField()

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "contact_us"
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} - {self.subject}"