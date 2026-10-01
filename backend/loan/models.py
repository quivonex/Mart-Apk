from django.db import models


class LoanEnquiry(models.Model):

    LOAN_TYPE_CHOICES = [
        ("home_loan", "Home Loan"),
        ("property_loan", "Property Loan"),
        ("land_loan", "Land Loan"),
        ("construction_loan", "Construction Loan"),
        ("loan_against_property", "Loan Against Property"),
    ]

    EMPLOYMENT_TYPE_CHOICES = [
        ("salaried", "Salaried"),
        ("self_employed", "Self Employed"),
        ("business", "Business"),
        ("professional", "Professional"),
        ("other", "Other"),
    ]

    STATUS_CHOICES = [
        ("new", "New"),
        ("contacted", "Contacted"),
        ("document_pending", "Document Pending"),
        ("under_review", "Under Review"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
        ("closed", "Closed"),
    ]

    # ==========================================
    # CUSTOMER DETAILS
    # ==========================================

    name = models.CharField(
        max_length=255
    )

    mobile = models.CharField(
        max_length=20
    )

    email = models.EmailField(
        null=True,
        blank=True
    )

    loan_type = models.CharField(
        max_length=50,
        choices=LOAN_TYPE_CHOICES
    )

    loan_amount = models.DecimalField(
        max_digits=15,
        decimal_places=2
    )

    tenure_years = models.PositiveIntegerField(
        null=True,
        blank=True
    )


    monthly_income = models.DecimalField(
        max_digits=15,
        decimal_places=2,
        null=True,
        blank=True
    )
    

    city = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    state = models.CharField(
        max_length=100,
        null=True,
        blank=True
    )

    pincode = models.CharField(
        max_length=10,
        null=True,
        blank=True
    )

  

    status = models.CharField(
        max_length=50,
        choices=STATUS_CHOICES,
        default="new"
    )

    remarks = models.TextField(
        null=True,
        blank=True
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def __str__(self):
        return f"{self.name} - {self.loan_amount}"