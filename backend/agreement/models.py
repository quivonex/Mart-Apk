from django.db import models

class CompanyAgreement(models.Model):

    agreement_number = models.CharField(max_length=100,unique=True)
    company = models.ForeignKey('company.Company',on_delete=models.CASCADE,related_name='company_agreements')
    agreement_role = models.CharField(max_length=100,default='company')
    apply_on_all_products = models.BooleanField(default=True)
    agreement_start_date = models.DateField()
    agreement_end_date = models.DateField()
    company_owner_name = models.CharField(max_length=255)
    company_address = models.TextField()
    # global_profit = models.DecimalField(max_digits=5,decimal_places=2,blank=True,null=True)
    seller_adhar_number = models.CharField(max_length=20,blank=True,null=True)
    owner_adhar_number = models.CharField(max_length=20,blank=True,null=True)
    seller_pan_number = models.CharField(max_length=20,blank=True,null=True)
    owner_pan_number = models.CharField(max_length=20,blank=True,null=True)
    # profit_share_percentage = models.DecimalField(max_digits=5,decimal_places=2)
    # selling_commission_percentage = models.DecimalField(max_digits=5,decimal_places=2)
    additional_points = models.TextField(blank=True,null=True)
    qnx_mart_representative = models.CharField(max_length=255,blank=True,null=True)
    qnx_mart_sign_s3_key = models.CharField(max_length=500,null=True,blank=True)
    company_sign_s3_key = models.CharField(max_length=500,null=True,blank=True)
    qnx_mart_picture_s3_key = models.CharField(max_length=500,null=True,blank=True)
    company_picture_s3_key = models.CharField(max_length=500,null=True,blank=True)
    uploaded_agreement_pdf_s3_key = models.CharField(max_length=500,null=True,blank=True)
    remarks = models.TextField(blank=True,null=True)
    status = models.CharField(max_length=20,choices=[
            ('pending', 'Pending'),
            ('approved', 'Approved'),
            ('rejected', 'Rejected'),
        ],
        default='pending'
    )
    created_by = models.ForeignKey('accounts.User',on_delete=models.SET_NULL,null=True,related_name='created_company_agreements')
    approved_by = models.ForeignKey('accounts.User',on_delete=models.SET_NULL,null=True,blank=True,related_name='approved_company_agreements')
    approved_at = models.DateTimeField(null=True,blank=True)
    rejection_reason = models.TextField(blank=True,null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.agreement_number


class AgreementProduct(models.Model):
    agreement = models.ForeignKey(CompanyAgreement,on_delete=models.CASCADE,related_name='agreement_products')
    product = models.ForeignKey('product.Product',on_delete=models.CASCADE,related_name='agreement_products')
    profit_percentage = models.DecimalField(max_digits=5, decimal_places=2, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['agreement', 'product'],
                name='unique_company_agreement_product'
            )
        ]

    def __str__(self):
        return f"{self.agreement.agreement_number} - {self.product.name}"
    
class MarketingPartnerAgreement(models.Model):

    agreement_number = models.CharField(max_length=100,unique=True)
    marketing_partner = models.ForeignKey('enquiry.MarketingPartner',on_delete=models.CASCADE,related_name='marketing_partner_agreements')
    agreement_role = models.CharField(max_length=100,default='marketing_partner')
    agreement_start_date = models.DateField()
    agreement_end_date = models.DateField()
    adhar_number = models.CharField(max_length=20,blank=True,null=True)
    pan_number = models.CharField(max_length=20,blank=True,null=True)
    marketing_partner_name = models.CharField(max_length=255)
    marketing_partner_address = models.TextField(blank=True,null=True)
    company_commission_percentage = models.DecimalField(max_digits=5,decimal_places=2,default=0)
    profit_share_percentage = models.DecimalField(max_digits=5,decimal_places=2,default=0)
    selling_commission_percentage = models.DecimalField(max_digits=5,decimal_places=2,default=0)
    additional_points = models.TextField(blank=True,null=True)
    qnx_mart_representative = models.CharField(max_length=255,blank=True,null=True)
    qnx_mart_sign_s3_key = models.CharField(max_length=500,null=True,blank=True)
    marketing_partner_sign_s3_key = models.CharField(max_length=500,null=True,blank=True)
    qnx_mart_picture_s3_key = models.CharField(max_length=500,null=True,blank=True)
    marketing_partner_picture_s3_key = models.CharField(max_length=500,null=True,blank=True)
    uploaded_agreement_pdf_s3_key = models.CharField(max_length=500,null=True,blank=True)
    remarks = models.TextField(blank=True,null=True)
    status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Pending'),
            ('approved', 'Approved'),
            ('rejected', 'Rejected'),
        ],
        default='pending'
    )
    created_by = models.ForeignKey('accounts.User',on_delete=models.SET_NULL,null=True,related_name='created_marketing_partner_agreements')
    approved_by = models.ForeignKey('accounts.User',on_delete=models.SET_NULL,null=True,blank=True,related_name='approved_marketing_partner_agreements')
    approved_at = models.DateTimeField(null=True,blank=True)
    rejection_reason = models.TextField(blank=True,null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.agreement_number    