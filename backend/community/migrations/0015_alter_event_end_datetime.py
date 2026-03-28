from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("community", "0014_homepage_donate_url"),
    ]

    operations = [
        migrations.AlterField(
            model_name="event",
            name="end_datetime",
            field=models.DateTimeField(null=True, blank=True),
        ),
    ]
