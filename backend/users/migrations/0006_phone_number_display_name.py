"""Replace email-based identity with phone_number + display_name.

Steps:
1. Add phone_number (non-unique initially, default='')
2. Add display_name
3. Backfill existing users with unique placeholder phone numbers
4. Make phone_number unique, remove default
5. Make email non-unique + optional
6. Remove username, first_name, last_name
"""

from django.db import migrations, models


def backfill_phone_numbers(apps, schema_editor):
    User = apps.get_model("users", "User")
    for i, user in enumerate(User.objects.filter(phone_number="").order_by("created_at"), start=1):
        user.phone_number = f"+1000000000{i}"
        user.save(update_fields=["phone_number"])


def reverse_backfill(apps, schema_editor):
    pass  # No reverse needed


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0005_assign_admin_role_to_superusers"),
    ]

    operations = [
        # Step 1: Add phone_number with default (not yet unique)
        migrations.AddField(
            model_name="user",
            name="phone_number",
            field=models.CharField(default="", max_length=20),
            preserve_default=False,
        ),
        # Step 2: Add display_name
        migrations.AddField(
            model_name="user",
            name="display_name",
            field=models.CharField(blank=True, max_length=64),
        ),
        # Step 3: Backfill existing users
        migrations.RunPython(backfill_phone_numbers, reverse_backfill),
        # Step 4: Make phone_number unique
        migrations.AlterField(
            model_name="user",
            name="phone_number",
            field=models.CharField(max_length=20, unique=True),
        ),
        # Step 5: Make email non-unique + optional
        migrations.AlterField(
            model_name="user",
            name="email",
            field=models.EmailField(blank=True, max_length=254),
        ),
        # Step 6: Remove old fields
        migrations.RemoveField(model_name="user", name="username"),
        migrations.RemoveField(model_name="user", name="first_name"),
        migrations.RemoveField(model_name="user", name="last_name"),
    ]
