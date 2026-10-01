from django.db import models

class Branch(models.Model):
    company = models.ForeignKey('company.Company', on_delete=models.CASCADE,null=True, blank=True, related_name="branches")
    name = models.CharField(max_length=200)
    address = models.TextField(blank=True)
    phone_number = models.CharField(max_length=20, blank=True)
    email = models.EmailField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name