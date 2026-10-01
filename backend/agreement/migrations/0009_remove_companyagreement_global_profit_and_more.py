from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('agreement', '0008_marketingpartneragreement_and_more'),
    ]

    operations = [
        migrations.SeparateDatabaseAndState(
            database_operations=[],
            state_operations=[
                migrations.RemoveField(
                    model_name='companyagreement',
                    name='global_profit',
                ),
                migrations.RemoveField(
                    model_name='companyagreement',
                    name='profit_share_percentage',
                ),
                migrations.RemoveField(
                    model_name='companyagreement',
                    name='selling_commission_percentage',
                ),
                migrations.DeleteModel(
                    name='Agreement',
                ),
            ],
        ),
    ]