from django.db import migrations

ALL_PERMISSION_KEYS = [
    "create_user",
    "manage_users",
    "manage_roles",
    "approve_join_requests",
    "manage_events",
]


def create_default_roles(apps, schema_editor):
    Role = apps.get_model("users", "Role")
    Role.objects.create(name="member", is_default=True, permissions=[])
    Role.objects.create(name="admin", is_default=True, permissions=ALL_PERMISSION_KEYS)


def delete_default_roles(apps, schema_editor):
    Role = apps.get_model("users", "Role")
    Role.objects.filter(name__in=["member", "admin"]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("users", "0002_add_role_model"),
    ]

    operations = [
        migrations.RunPython(create_default_roles, reverse_code=delete_default_roles),
    ]
