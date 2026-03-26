# Generated migration for EditablePage model

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("community", "0011_homepage_join_content"),
    ]

    operations = [
        migrations.CreateModel(
            name="EditablePage",
            fields=[
                (
                    "id",
                    models.AutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("slug", models.SlugField(max_length=100, unique=True)),
                ("content", models.TextField(default="")),
                (
                    "visibility",
                    models.CharField(
                        choices=[("public", "Public"), ("members_only", "Members only")],
                        default="public",
                        max_length=20,
                    ),
                ),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "ordering": ["slug"],
            },
        ),
    ]
