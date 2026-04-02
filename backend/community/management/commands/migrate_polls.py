"""Migrate survey-based datetime polls to the new EventPoll model.

Usage:
    cd backend && uv run python manage.py migrate_polls [--dry-run]
"""

import datetime

from django.core.management.base import BaseCommand

from community.models import (
    DatetimePollResult,
    EventPoll,
    PollAvailability,
    PollOption,
    PollVote,
    Survey,
    SurveyQuestionType,
)


def _parse_iso(s: str) -> datetime.datetime:
    """Parse an ISO 8601 string to a UTC-aware datetime."""
    dt = datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        return dt.replace(tzinfo=datetime.UTC)
    return dt.astimezone(datetime.UTC)


def _migrate_votes(poll: EventPoll, survey: Survey, question, option_map: dict) -> None:
    """Migrate votes from SurveyResponse.answers to PollVote rows."""
    for response in survey.responses.all():
        if response.user is None:
            continue
        answer_data = response.answers.get(str(question.id))
        if not answer_data:
            continue
        answer = answer_data.get("answer")
        if isinstance(answer, dict):
            _migrate_dict_votes(option_map, response, answer)
        elif isinstance(answer, str):
            _migrate_legacy_votes(option_map, response, answer)


def _migrate_dict_votes(option_map: dict, response, answer: dict) -> None:
    for iso, availability in answer.items():
        if availability not in PollAvailability.VALID:
            continue
        try:
            key = _parse_iso(iso).isoformat()
        except (ValueError, TypeError):
            continue
        if key in option_map:
            PollVote.objects.get_or_create(
                option=option_map[key],
                user=response.user,
                defaults={"availability": availability},
            )


def _migrate_legacy_votes(option_map: dict, response, answer: str) -> None:
    for iso in answer.split(","):
        iso = iso.strip()
        try:
            key = _parse_iso(iso).isoformat()
        except (ValueError, TypeError):
            continue
        if key in option_map:
            PollVote.objects.get_or_create(
                option=option_map[key],
                user=response.user,
                defaults={"availability": PollAvailability.YES},
            )


def _migrate_finalization(poll: EventPoll, survey: Survey, option_map: dict) -> None:
    """Copy finalization state from DatetimePollResult to EventPoll."""
    try:
        result: DatetimePollResult = survey.poll_result
    except DatetimePollResult.DoesNotExist:
        return
    winning_key = _parse_iso(result.winning_datetime.isoformat()).isoformat()
    winning_option = option_map.get(winning_key)
    if winning_option is None:
        for key, opt in option_map.items():
            if key[:16] == winning_key[:16]:
                winning_option = opt
                break
    if winning_option:
        poll.winning_option = winning_option
        poll.finalized_by = result.finalized_by
        poll.finalized_at = result.finalized_at
        poll.is_active = False
        poll.save(update_fields=["winning_option", "finalized_by", "finalized_at", "is_active"])


def _migrate_one(survey: Survey) -> EventPoll:
    """Migrate a single survey poll to EventPoll. Returns the created EventPoll."""
    event = survey.linked_event
    question = survey.questions.filter(field_type=SurveyQuestionType.DATETIME_POLL).first()
    poll = EventPoll.objects.create(
        event=event,
        created_by=survey.created_by,
        is_active=survey.is_active,
    )
    option_map: dict[str, PollOption] = {}
    for i, iso in enumerate(question.options or []):
        try:
            dt = _parse_iso(iso)
        except (ValueError, TypeError):
            continue
        option = PollOption.objects.create(poll=poll, datetime=dt, display_order=i)
        option_map[dt.isoformat()] = option
    _migrate_votes(poll, survey, question, option_map)
    _migrate_finalization(poll, survey, option_map)
    return poll


class Command(BaseCommand):
    help = "Migrate survey-based datetime polls to the EventPoll model"

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Report what would be migrated without making changes",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        if dry_run:
            self.stdout.write(self.style.WARNING("DRY RUN — no changes will be made\n"))

        surveys = (
            Survey.objects.filter(
                questions__field_type=SurveyQuestionType.DATETIME_POLL,
                linked_event__isnull=False,
            )
            .select_related("linked_event", "created_by")
            .prefetch_related("questions", "responses__user")
            .distinct()
        )

        migrated = 0
        skipped = 0

        for survey in surveys:
            event = survey.linked_event
            skip_reason = self._skip_reason(survey, event)
            if skip_reason:
                self.stdout.write(f"  skipping {event.title!r} — {skip_reason}")
                skipped += 1
                continue

            self.stdout.write(f"  migrating poll for event: {event.title!r}")
            if not dry_run:
                _migrate_one(survey)
            migrated += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"\nmigrated {migrated} poll{'s' if migrated != 1 else ''}, "
                f"skipped {skipped}"
            )
        )

    def _skip_reason(self, survey: Survey, event) -> str | None:
        question = survey.questions.filter(
            field_type=SurveyQuestionType.DATETIME_POLL
        ).first()
        if question is None:
            return "no poll question found"
        if hasattr(event, "poll"):
            return "EventPoll already exists"
        if not (question.options or []):
            return "no options defined"
        return None
