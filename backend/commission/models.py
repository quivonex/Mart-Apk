from decimal import Decimal

from django.db import models
from shiprocket.models import ShipOrder


# ============================================================
# COMPANY WALLET
# ============================================================

class CompanyWallet(models.Model):

    company = models.OneToOneField(
        "company.Company",
        on_delete=models.CASCADE,
        related_name="wallet"
    )

    # Amount payable to company
    balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00")
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.company.name} - ₹{self.balance}"


# ============================================================
# COMPANY WALLET TRANSACTION
# ============================================================

class WalletTransaction(models.Model):

    TRANSACTION_TYPES = (
        ("CREDIT", "Credit"),
        ("DEBIT", "Debit"),
    )

    wallet = models.ForeignKey(
        CompanyWallet,
        on_delete=models.CASCADE,
        related_name="transactions"
    )

    order = models.ForeignKey(
        "shiprocket.ShipOrder",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="wallet_transactions"
    )

    product = models.ForeignKey(
        "product.Product",
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    transaction_type = models.CharField(
        max_length=10,
        choices=TRANSACTION_TYPES
    )

    # Company ला मिळणारी actual amount
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    # Our commission %
    commission_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True
    )

    # Company ला मिळालेली %
    company_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True
    )

    # Total product sale amount
    sale_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )

    # Our commission amount
    platform_commission = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )

    description = models.TextField(
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )


# ============================================================
# PLATFORM / QNX MART WALLET
# ============================================================

class PlatformWallet(models.Model):

    # Single platform wallet
    balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00")
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f"QNX Mart Wallet - ₹{self.balance}"


# ============================================================
# PLATFORM WALLET TRANSACTION
# ============================================================

class PlatformWalletTransaction(models.Model):

    TRANSACTION_TYPES = (
        ("CREDIT", "Credit"),
        ("DEBIT", "Debit"),
    )

    wallet = models.ForeignKey(
        PlatformWallet,
        on_delete=models.CASCADE,
        related_name="transactions"
    )

    order = models.ForeignKey(
        "shiprocket.ShipOrder",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="platform_wallet_transactions"
    )

    product = models.ForeignKey(
        "product.Product",
        on_delete=models.SET_NULL,
        null=True,
        blank=True
    )

    transaction_type = models.CharField(
        max_length=10,
        choices=TRANSACTION_TYPES
    )

    # Our commission amount
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    commission_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True
    )

    sale_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )

    description = models.TextField(
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return f"{self.transaction_type} - ₹{self.amount}"
    
    
    
from decimal import Decimal

from django.db import models

class MarketingPartnerWallet(models.Model):

    marketing_partner = models.OneToOneField(
        "enquiry.MarketingPartner",
        on_delete=models.CASCADE,
        related_name="wallet"
    )

    balance = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        default=Decimal("0.00")
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return (
            f"{self.marketing_partner.full_name} "
            f"- ₹{self.balance}"
        )


class MarketingPartnerWalletTransaction(models.Model):

    TRANSACTION_TYPES = (
        ("CREDIT", "Credit"),
        ("DEBIT", "Debit"),
    )

    wallet = models.ForeignKey(
        MarketingPartnerWallet,
        on_delete=models.CASCADE,
        related_name="transactions"
    )

    company = models.ForeignKey(
        "company.Company",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="marketing_partner_commission_transactions"
    )

    transaction_type = models.CharField(
        max_length=10,
        choices=TRANSACTION_TYPES
    )

    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2
    )

    commission_percentage = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True
    )

    base_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        null=True,
        blank=True
    )

    commission_type = models.CharField(
        max_length=50,
        null=True,
        blank=True
    )

    description = models.TextField(
        blank=True,
        null=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return (
            f"{self.transaction_type} "
            f"- ₹{self.amount}"
        )    