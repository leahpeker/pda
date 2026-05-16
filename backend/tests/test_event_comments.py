"""End-to-end tests for the event comments API."""

import pytest
from community.models import Event

from tests.conftest import future_iso


@pytest.fixture
def event(db, test_user):
    return Event.objects.create(
        title="Test Event",
        start_datetime=future_iso(days=30),
        created_by=test_user,
    )


@pytest.mark.django_db
class TestGetComments:
    def test_get_empty_unauthed(self, api_client, event):
        response = api_client.get(f"/api/community/events/{event.id}/comments/")
        assert response.status_code == 200, response.content
        body = response.json()
        assert body["items"] == []
        assert body["can_post"] is False
        assert body["cannot_post_reason"] == "login_required"
