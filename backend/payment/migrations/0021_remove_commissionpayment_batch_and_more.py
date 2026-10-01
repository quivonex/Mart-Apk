from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('payment', '0020_razorpaypayment'),
    ]

    operations = [
        migrations.RunSQL(
            sql="""
                SET FOREIGN_KEY_CHECKS = 0;

                DROP TABLE IF EXISTS payment_marketingpartnercommission;
                DROP TABLE IF EXISTS payment_marketingpartnerwallettransaction;
                DROP TABLE IF EXISTS payment_marketingpartnerwalletwithdrawrequest;
                DROP TABLE IF EXISTS payment_marketingpartnerwallet;
                DROP TABLE IF EXISTS payment_shipordercommission;
                DROP TABLE IF EXISTS payment_commissionpayment;
                DROP TABLE IF EXISTS payment_commissionbatch;

                SET FOREIGN_KEY_CHECKS = 1;
            """,
            reverse_sql=migrations.RunSQL.noop,
        ),

        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.DeleteModel(name='CommissionBatch'),
                migrations.DeleteModel(name='CommissionPayment'),
                migrations.DeleteModel(name='MarketingPartnerCommission'),
                migrations.DeleteModel(name='MarketingPartnerWalletTransaction'),
                migrations.DeleteModel(name='MarketingPartnerWallet'),
                migrations.DeleteModel(name='MarketingPartnerWalletWithdrawRequest'),
                migrations.DeleteModel(name='ShipOrderCommission'),
            ],
        ),
    ]