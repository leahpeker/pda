"""Tests for the COMMENT_REPLY notification path.

Covers both the standalone notify_comment_reply helper and the end-to-end
flow through the reply endpoint. Extracted out of test_in_app_notifications
and test_event_comments to keep those files under the 500-line cap.
"""

import json

import pytest
from community.models import Event, EventComment, EventRSVP, RSVPStatus
from ninja_jwt.tokens import RefreshToken
from notifications.models import Notification, NotificationType
from notifications.service import notify_comment_reply
from users.models import User

from tests.conftest import future_iso


@pytest.mark.django_db
class TestNotifyCommentReply:
    def test_notifies_parent_author(self, test_user, db):
        replier = User.objects.create_user(
            phone_number="+12025550707",
            password="replierpass",
            display_name="Replier",
        )
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="parent")
        reply = EventComment.objects.create(
            event=event, author=replier, body="reply", parent=parent
        )
        notify_comment_reply(reply)
        notifs = Notification.objects.filter(
            recipient=test_user, notification_type=NotificationType.COMMENT_REPLY
        )
        assert notifs.count() == 1
        n = notifs.first()
        assert n.event_id == event.id
        assert n.related_user_id == replier.id
        assert "replier" in n.message.lower() or "Replier" in n.message

    def test_no_self_notify(self, test_user, db):
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        parent = EventComment.objects.create(event=event, author=test_user, body="p")
        reply = EventComment.objects.create(event=event, author=test_user, body="r", parent=parent)
        notify_comment_reply(reply)
        assert (
            Notification.objects.filter(
                recipient=test_user, notification_type=NotificationType.COMMENT_REPLY
            ).count()
            == 0
        )

    def test_noop_for_top_level(self, test_user, db):
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        comment = EventComment.objects.create(event=event, author=test_user, body="top")
        notify_comment_reply(comment)
        assert (
            Notification.objects.filter(notification_type=NotificationType.COMMENT_REPLY).count()
            == 0
        )


@pytest.mark.django_db
class TestReplyEndpointTriggersNotification:
    def test_reply_creates_notification_for_parent_author(self, api_client, test_user, db):
        # Two RSVPd users on the same event: `author` posts the parent comment,
        # `replier` posts the reply. The reply endpoint should create a
        # COMMENT_REPLY notification for `author`.
        event = Event.objects.create(
            title="E",
            start_datetime=future_iso(days=10),
            created_by=test_user,
        )
        author = User.objects.create_user(
            phone_number="+12025550808",
            password="authorpass",
            display_name="Author",
        )
        replier = User.objects.create_user(
            phone_number="+12025550303",
            password="replierpass",
            display_name="Replier",
        )
        EventRSVP.objects.create(event=event, user=author, status=RSVPStatus.ATTENDING)
        EventRSVP.objects.create(event=event, user=replier, status=RSVPStatus.ATTENDING)
        parent = EventComment.objects.create(event=event, author=author, body="parent")
        replier_headers = {
            "HTTP_AUTHORIZATION": f"Bearer {RefreshToken.for_user(replier).access_token}"  # type: ignore
        }
        response = api_client.post(
            f"/api/community/events/{event.id}/comments/{parent.id}/replies/",
            data=json.dumps({"body": "reply"}),
            content_type="application/json",
            **replier_headers,
        )
        assert response.status_code == 201
        notifs = Notification.objects.filter(
            recipient=author, notification_type=NotificationType.COMMENT_REPLY
        )
        assert notifs.count() == 1
