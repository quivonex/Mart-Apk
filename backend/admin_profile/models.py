# models.py
from django.db import models
from django.contrib.auth.hashers import make_password, check_password
from django.utils import timezone


class admin_Role(models.Model):
    role_name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.role_name


# Default Admin Role Function
def get_default_admin_role():
    from django.core.exceptions import ObjectDoesNotExist
    try:
        return admin_Role.objects.get(role_name='Admin').id
    except ObjectDoesNotExist:
        admin_role = admin_Role.objects.create(
            role_name='Admin',
            description='Super Admin'
        )
        return admin_role.id


class UserAdmin(models.Model):
    username = models.CharField(max_length=150, unique=True)
    password = models.CharField(max_length=128)
    name = models.CharField(max_length=200)
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=20)

    # ✅ Role Added
    role = models.ForeignKey(
        admin_Role,
        on_delete=models.SET_DEFAULT,
        default=get_default_admin_role,
        related_name="users"
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def set_password(self, raw_password, save=True):
        self.password = make_password(raw_password)
        if save:
            self.save()

    def check_password(self, raw_password):
        return check_password(raw_password, self.password)

    def __str__(self):
        return f"{self.username} - {self.role.role_name}"

class OTP(models.Model):
    user = models.ForeignKey(UserAdmin, on_delete=models.CASCADE, related_name='otps')
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_valid(self):
        """Check if OTP is still valid"""
        return timezone.now() <= self.expires_at

    def __str__(self):
        return f"{self.user.username} - {self.otp}"
    



class UploadImage(models.Model):
    image_s3_key = models.CharField(max_length=255, blank=True, null=True)
    title = models.CharField(max_length=150, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title if self.title else f"Image {self.id}"