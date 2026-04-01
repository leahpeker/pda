"""Tests for user management: create, bulk create, list, patch, delete, search, roles."""

import pytest
from users.permissions import PermissionKey
from users.roles import Role

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def manage_users_user(db):
    from users.models import User

    user = User.objects.create_user(
        phone_number="+12025550201",
        password="managerpass123",
        display_name="User Manager",
    )
    role = Role.objects.create(
        name="user_manager",
        permissions=[PermissionKey.MANAGE_USERS, PermissionKey.CREATE_USER],
    )
    user.roles.add(role)
    return user


@pytest.fixture
def manage_users_headers(manage_users_user):
    from ninja_jwt.tokens import RefreshToken

    refresh = RefreshToken.for_user(manage_users_user)
    return {"HTTP_AUTHORIZATION": f"Bearer {refresh.access_token}"}  # type: ignore


@pytest.fixture
def other_user(db):
    from users.models import User

    return User.objects.create_user(
        phone_number="+12025550301",
        password="otherpass123",
        display_name="Other User",
    )


# ---------------------------------------------------------------------------
# TestCreateUser
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestCreateUser:
    def test_create_user_invalid_phone(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/create-user/",
            {"phone_number": "not-a-phone"},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 400

    def test_create_user_with_role_id(self, api_client, manage_users_headers, db):
        role = Role.objects.create(name="custom_role", permissions=[])
        response = api_client.post(
            "/api/auth/create-user/",
            {"phone_number": "+12025550901", "role_id": str(role.id)},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 201

    def test_create_user_invalid_role_id(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/create-user/",
            {
                "phone_number": "+12025550902",
                "role_id": "00000000-0000-0000-0000-000000000000",
            },
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 400
        assert response.json()["detail"] == "Role not found."

    def test_create_user_sets_needs_onboarding(self, api_client, manage_users_headers):
        from users.models import User

        response = api_client.post(
            "/api/auth/create-user/",
            {"phone_number": "+12025550903"},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 201
        user = User.objects.get(phone_number="+12025550903")
        assert user.needs_onboarding is True

    def test_create_user_unauthenticated(self, api_client):
        response = api_client.post(
            "/api/auth/create-user/",
            {"phone_number": "+12025550904"},
            content_type="application/json",
        )
        assert response.status_code == 401


# ---------------------------------------------------------------------------
# TestBulkCreateUsers
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestBulkCreateUsers:
    def test_bulk_create_users_success(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": ["+12025551001", "+12025551002", "+12025551003"]},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 3
        assert data["failed"] == 0
        assert all(r["success"] for r in data["results"])
        assert all(len(r["magic_link_token"]) == 36 for r in data["results"] if r["success"])

    def test_bulk_create_users_requires_permission(self, api_client, auth_headers):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": ["+12025551101"]},
            content_type="application/json",
            **auth_headers,
        )
        assert response.status_code == 403

    def test_bulk_create_users_requires_auth(self, api_client):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": ["+12025551101"]},
            content_type="application/json",
        )
        assert response.status_code == 401

    def test_bulk_create_users_invalid_phone(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": ["+12025551201", "not-a-phone"]},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 1
        assert data["failed"] == 1
        failed = [r for r in data["results"] if not r["success"]]
        assert failed[0]["phone_number"] == "not-a-phone"

    def test_bulk_create_users_duplicate_phone(self, api_client, manage_users_headers, test_user):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": [test_user.phone_number, "+12025551301"]},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 1
        assert data["failed"] == 1
        failed = [r for r in data["results"] if not r["success"]]
        assert "already exists" in failed[0]["error"]

    def test_bulk_create_users_shared_temp_password(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": ["+12025551401", "+12025551402"]},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 2
        assert all(r.get("magic_link_token") for r in data["results"] if r["success"])

    def test_bulk_create_users_empty_list(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/bulk-create-users/",
            {"phone_numbers": []},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["created"] == 0
        assert data["failed"] == 0


# ---------------------------------------------------------------------------
# TestSearchUsers
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestSearchUsers:
    def test_search_returns_results(self, api_client, auth_headers, other_user):
        response = api_client.get(
            "/api/auth/users/search/?q=Other",
            **auth_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert any(u["display_name"] == "Other User" for u in data)

    def test_search_excludes_self(self, api_client, auth_headers, test_user):
        response = api_client.get(
            "/api/auth/users/search/?q=Test",
            **auth_headers,
        )
        assert response.status_code == 200
        ids = [u["id"] for u in response.json()]
        assert str(test_user.pk) not in ids

    def test_search_empty_query_returns_all_others(self, api_client, auth_headers, other_user):
        response = api_client.get("/api/auth/users/search/", **auth_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_search_requires_auth(self, api_client):
        response = api_client.get("/api/auth/users/search/?q=test")
        assert response.status_code == 401

    def test_search_limits_to_ten_results(self, api_client, auth_headers, db):
        from users.models import User

        for i in range(15):
            User.objects.create_user(
                phone_number=f"+1555001{i:04d}",
                password="pass",
                display_name=f"Searchable User {i}",
            )
        response = api_client.get("/api/auth/users/search/?q=Searchable", **auth_headers)
        assert response.status_code == 200
        assert len(response.json()) <= 10


# ---------------------------------------------------------------------------
# TestUpdateUser
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestUpdateUser:
    def test_update_user_not_found(self, api_client, manage_users_headers):
        response = api_client.patch(
            "/api/auth/users/00000000-0000-0000-0000-000000000000/",
            {"display_name": "Ghost"},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 404
        assert response.json()["detail"] == "User not found."

    def test_update_user_duplicate_phone(
        self, api_client, manage_users_headers, test_user, other_user
    ):
        response = api_client.patch(
            f"/api/auth/users/{other_user.pk}/",
            {"phone_number": test_user.phone_number},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 400
        assert "already exists" in response.json()["detail"]

    def test_update_user_invalid_phone(self, api_client, manage_users_headers, other_user):
        response = api_client.patch(
            f"/api/auth/users/{other_user.pk}/",
            {"phone_number": "not-a-phone"},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 400

    def test_update_user_is_active(self, api_client, manage_users_headers, other_user):
        response = api_client.patch(
            f"/api/auth/users/{other_user.pk}/",
            {"is_active": False},
            content_type="application/json",
            **manage_users_headers,
        )
        assert response.status_code == 200
        other_user.refresh_from_db()
        assert other_user.is_active is False

    def test_update_user_requires_auth(self, api_client, other_user):
        response = api_client.patch(
            f"/api/auth/users/{other_user.pk}/",
            {"display_name": "Hacker"},
            content_type="application/json",
        )
        assert response.status_code == 401

    def test_update_user_requires_permission(self, api_client, auth_headers, other_user):
        response = api_client.patch(
            f"/api/auth/users/{other_user.pk}/",
            {"display_name": "Blocked"},
            content_type="application/json",
            **auth_headers,
        )
        assert response.status_code == 403


# ---------------------------------------------------------------------------
# TestDeleteUser
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestDeleteUser:
    def test_delete_user_not_found(self, api_client, manage_users_headers):
        response = api_client.delete(
            "/api/auth/users/00000000-0000-0000-0000-000000000000/",
            **manage_users_headers,
        )
        assert response.status_code == 404
        assert response.json()["detail"] == "User not found."

    def test_delete_user_requires_auth(self, api_client, other_user):
        response = api_client.delete(f"/api/auth/users/{other_user.pk}/")
        assert response.status_code == 401

    def test_delete_user_requires_permission(self, api_client, auth_headers, other_user):
        response = api_client.delete(
            f"/api/auth/users/{other_user.pk}/",
            **auth_headers,
        )
        assert response.status_code == 403


# ---------------------------------------------------------------------------
# TestResetPassword
# ---------------------------------------------------------------------------


@pytest.mark.django_db
class TestResetPassword:
    def test_reset_password_not_found(self, api_client, manage_users_headers):
        response = api_client.post(
            "/api/auth/users/00000000-0000-0000-0000-000000000000/reset-password/",
            **manage_users_headers,
        )
        assert response.status_code == 404
        assert response.json()["detail"] == "User not found."

    def test_reset_password_requires_auth(self, api_client, other_user):
        response = api_client.post(f"/api/auth/users/{other_user.pk}/reset-password/")
        assert response.status_code == 401

    def test_reset_password_sets_needs_onboarding(
        self, api_client, manage_users_headers, other_user
    ):
        # Reset password should let the user log in with new temp password
        response = api_client.post(
            f"/api/auth/users/{other_user.pk}/reset-password/",
            **manage_users_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["magic_link_token"]) == 36  # UUID format
        other_user.refresh_from_db()
        assert not other_user.has_usable_password()
