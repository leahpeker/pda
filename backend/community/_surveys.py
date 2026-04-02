"""Survey CRUD, questions, and response endpoints."""

from uuid import UUID

from config.media_proxy import media_path
from ninja import Router
from ninja.responses import Status
from ninja_jwt.authentication import JWTAuth
from users.permissions import PermissionKey

from community._shared import ErrorOut, _authenticated_user, _optional_jwt
from community._survey_schemas import (
    FinalizePollIn,
    PollResultOut,
    PollResultsOut,
    SurveyAnswersIn,
    SurveyIn,
    SurveyListOut,
    SurveyOut,
    SurveyPatchIn,
    SurveyQuestionIn,
    SurveyQuestionOrderIn,
    SurveyQuestionOut,
    SurveyResponseOut,
    VoterOut,
)
from community._survey_validators import _build_survey_answers, _validate_survey_answers
from community.models import (
    DatetimePollResult,
    Event,
    PollAvailability,
    Survey,
    SurveyQuestion,
    SurveyQuestionType,
    SurveyResponse,
    SurveyVisibility,
)

router = Router()


def _survey_question_out(q: SurveyQuestion) -> SurveyQuestionOut:
    return SurveyQuestionOut(
        id=str(q.id),
        label=q.label,
        field_type=q.field_type,
        options=q.options or [],
        required=q.required,
        display_order=q.display_order,
    )


def _poll_result_out(result: "DatetimePollResult") -> PollResultOut:
    return PollResultOut(
        id=str(result.id),
        winning_datetime=result.winning_datetime,
        finalized_by_id=str(result.finalized_by_id) if result.finalized_by_id else None,
        finalized_at=result.finalized_at,
    )


def _survey_out(
    survey: Survey,
    include_questions: bool = False,
    requesting_user=None,
) -> SurveyOut:
    questions = (
        [_survey_question_out(q) for q in survey.questions.all()] if include_questions else []
    )
    poll_result = None
    try:
        poll_result = _poll_result_out(survey.poll_result)
    except DatetimePollResult.DoesNotExist:
        pass
    my_response_id = None
    my_answers = None
    if requesting_user is not None:
        existing = survey.responses.filter(user=requesting_user).first()
        if existing:
            my_response_id = str(existing.id)
            my_answers = existing.answers
    return SurveyOut(
        id=str(survey.id),
        title=survey.title,
        description=survey.description,
        slug=survey.slug,
        visibility=survey.visibility,
        is_active=survey.is_active,
        one_response_per_user=survey.one_response_per_user,
        linked_event_id=str(survey.linked_event_id) if survey.linked_event_id else None,
        created_by_id=str(survey.created_by_id) if survey.created_by_id else None,
        created_at=survey.created_at,
        questions=questions,
        response_count=survey.responses.count(),
        poll_result=poll_result,
        my_response_id=my_response_id,
        my_answers=my_answers,
    )


def _apply_linked_event_update(updates: dict) -> tuple[dict, str | None]:
    """Resolve linked_event_id → linked_event object in update dict. Returns (updates, error_detail)."""
    eid = updates.pop("linked_event_id")
    if not eid:
        updates["linked_event"] = None
        return updates, None
    try:
        updates["linked_event"] = Event.objects.get(id=eid)
    except Event.DoesNotExist:
        return updates, "Event not found."
    return updates, None


# -- Admin endpoints --


@router.get(
    "/surveys/admin/",
    response={200: list[SurveyListOut], 403: ErrorOut},
    auth=JWTAuth(),
)
def list_surveys_admin(request):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    surveys = Survey.objects.all()
    return Status(
        200,
        [
            SurveyListOut(
                id=str(s.id),
                title=s.title,
                slug=s.slug,
                visibility=s.visibility,
                is_active=s.is_active,
                linked_event_id=str(s.linked_event_id) if s.linked_event_id else None,
                created_at=s.created_at,
                response_count=s.responses.count(),
            )
            for s in surveys
        ],
    )


@router.post(
    "/surveys/",
    response={201: SurveyOut, 403: ErrorOut, 400: ErrorOut},
    auth=JWTAuth(),
)
def create_survey(request, payload: SurveyIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    if Survey.objects.filter(slug=payload.slug).exists():
        return Status(400, ErrorOut(detail="A survey with that slug already exists."))
    linked_event = None
    if payload.linked_event_id:
        try:
            linked_event = Event.objects.get(id=payload.linked_event_id)
        except Event.DoesNotExist:
            return Status(400, ErrorOut(detail="Event not found."))
    survey = Survey.objects.create(
        title=payload.title,
        description=payload.description,
        slug=payload.slug,
        visibility=payload.visibility,
        is_active=payload.is_active,
        one_response_per_user=payload.one_response_per_user,
        linked_event=linked_event,
        created_by=request.auth,
    )
    return Status(201, _survey_out(survey, include_questions=True))


@router.get(
    "/surveys/{survey_id}/admin/",
    response={200: SurveyOut, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def get_survey_admin(request, survey_id: UUID):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        survey = Survey.objects.prefetch_related("questions").get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    return Status(200, _survey_out(survey, include_questions=True))


@router.patch(
    "/surveys/{survey_id}/",
    response={200: SurveyOut, 403: ErrorOut, 404: ErrorOut, 400: ErrorOut},
    auth=JWTAuth(),
)
def update_survey(request, survey_id: UUID, payload: SurveyPatchIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        survey = Survey.objects.get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    updates = payload.model_dump(exclude_unset=True)
    if "linked_event_id" in updates:
        updates, err = _apply_linked_event_update(updates)
        if err:
            return Status(400, ErrorOut(detail=err))
    if "slug" in updates and updates["slug"] != survey.slug:
        if Survey.objects.filter(slug=updates["slug"]).exists():
            return Status(400, ErrorOut(detail="A survey with that slug already exists."))
    for key, value in updates.items():
        setattr(survey, key, value)
    survey.save(update_fields=list(updates.keys()))
    return Status(200, _survey_out(survey, include_questions=True))


@router.delete(
    "/surveys/{survey_id}/",
    response={204: None, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def delete_survey(request, survey_id: UUID):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        survey = Survey.objects.get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    survey.delete()
    return Status(204, None)


# -- Survey questions --


@router.post(
    "/surveys/{survey_id}/questions/",
    response={201: SurveyQuestionOut, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def create_survey_question(request, survey_id: UUID, payload: SurveyQuestionIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        survey = Survey.objects.get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    max_order = survey.questions.count()
    q = SurveyQuestion.objects.create(
        survey=survey,
        label=payload.label,
        field_type=payload.field_type,
        options=payload.options,
        required=payload.required,
        display_order=max_order,
    )
    return Status(201, _survey_question_out(q))


@router.patch(
    "/surveys/{survey_id}/questions/{question_id}/",
    response={200: SurveyQuestionOut, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def update_survey_question(request, survey_id: UUID, question_id: UUID, payload: SurveyQuestionIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        q = SurveyQuestion.objects.get(id=question_id, survey_id=survey_id)
    except SurveyQuestion.DoesNotExist:
        return Status(404, ErrorOut(detail="Question not found."))
    q.label = payload.label
    q.field_type = payload.field_type
    q.options = payload.options
    q.required = payload.required
    q.save()
    return Status(200, _survey_question_out(q))


@router.delete(
    "/surveys/{survey_id}/questions/{question_id}/",
    response={204: None, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def delete_survey_question(request, survey_id: UUID, question_id: UUID):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        q = SurveyQuestion.objects.get(id=question_id, survey_id=survey_id)
    except SurveyQuestion.DoesNotExist:
        return Status(404, ErrorOut(detail="Question not found."))
    q.delete()
    return Status(204, None)


@router.put(
    "/surveys/{survey_id}/questions/order/",
    response={200: list[SurveyQuestionOut], 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def reorder_survey_questions(request, survey_id: UUID, payload: SurveyQuestionOrderIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        Survey.objects.get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    for idx, qid in enumerate(payload.question_ids):
        SurveyQuestion.objects.filter(id=qid, survey_id=survey_id).update(display_order=idx)
    questions = SurveyQuestion.objects.filter(survey_id=survey_id)
    return Status(200, [_survey_question_out(q) for q in questions])


# -- Survey responses (admin) --


@router.get(
    "/surveys/{survey_id}/responses/",
    response={200: list[SurveyResponseOut], 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def list_survey_responses(request, survey_id: UUID):
    if not request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return Status(403, ErrorOut(detail="Permission denied."))
    try:
        survey = Survey.objects.get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    responses = survey.responses.select_related("user").all()
    return Status(
        200,
        [
            SurveyResponseOut(
                id=str(r.id),
                user_id=str(r.user_id) if r.user_id else None,
                user_name=(r.user.display_name or r.user.phone_number) if r.user else None,
                answers=r.answers,
                submitted_at=r.submitted_at,
            )
            for r in responses
        ],
    )


def _response_out(response: SurveyResponse, user_name: str | None) -> SurveyResponseOut:
    return SurveyResponseOut(
        id=str(response.id),
        user_id=str(response.user_id) if response.user_id else None,
        user_name=user_name,
        answers=response.answers,
        submitted_at=response.submitted_at,
    )


def _voter_out(user) -> VoterOut:
    return VoterOut(
        user_id=str(user.pk),
        name=user.display_name or user.phone_number,
        photo_url=media_path(user.profile_photo),
    )


def _tally_question(q: SurveyQuestion, responses: list[SurveyResponse]) -> PollResultsOut:
    options = q.options or []
    counts: dict[str, dict[str, int]] = {
        opt: {PollAvailability.YES: 0, PollAvailability.MAYBE: 0} for opt in options
    }
    voters: dict[str, list[VoterOut]] = {opt: [] for opt in options}
    for r in responses:
        answer_data = r.answers.get(str(q.id))
        if not answer_data:
            continue
        answer = answer_data.get("answer")
        voter = _voter_out(r.user) if r.user else None
        # Dict answer: {"iso": "yes"|"maybe"}
        if isinstance(answer, dict):
            for opt, availability in answer.items():
                if opt in counts and availability in PollAvailability.VALID:
                    counts[opt][availability] += 1
                    if voter:
                        voters[opt].append(voter)
        # Legacy comma-separated string answer: treat as "yes"
        elif isinstance(answer, str):
            for val in answer.split(","):
                val = val.strip()
                if val in counts:
                    counts[val][PollAvailability.YES] += 1
                    if voter:
                        voters[val].append(voter)
    return PollResultsOut(
        question_id=str(q.id),
        tallies=counts,
        voters=voters,
        total_responses=len(responses),
    )


def _has_finalize_permission(request, survey: Survey, event: Event | None) -> bool:
    if request.auth.has_permission(PermissionKey.MANAGE_SURVEYS):
        return True
    if request.auth.has_permission(PermissionKey.MANAGE_EVENTS):
        return True
    if survey.created_by_id == request.auth.pk:
        return True
    if event and event.created_by_id == request.auth.pk:
        return True
    if event and event.co_hosts.filter(pk=request.auth.pk).exists():
        return True
    return False


# -- Public endpoints --


@router.get(
    "/surveys/view/{slug}/",
    response={200: SurveyOut, 404: ErrorOut},
    auth=_optional_jwt,
)
def get_survey_public(request, slug: str):
    try:
        survey = Survey.objects.prefetch_related("questions").get(slug=slug, is_active=True)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    auth_user = _authenticated_user(request.auth)
    if survey.visibility == SurveyVisibility.MEMBERS_ONLY and auth_user is None:
        return Status(404, ErrorOut(detail="Survey not found."))
    return Status(200, _survey_out(survey, include_questions=True, requesting_user=auth_user))


@router.post(
    "/surveys/view/{slug}/respond/",
    response={200: SurveyResponseOut, 201: SurveyResponseOut, 400: ErrorOut, 404: ErrorOut},
    auth=_optional_jwt,
)
def submit_survey_response(request, slug: str, payload: SurveyAnswersIn):
    try:
        survey = Survey.objects.prefetch_related("questions").get(slug=slug, is_active=True)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    auth_user = _authenticated_user(request.auth)
    if survey.visibility == SurveyVisibility.MEMBERS_ONLY and auth_user is None:
        return Status(404, ErrorOut(detail="Survey not found."))
    questions = {str(q.id): q for q in survey.questions.all()}
    error = _validate_survey_answers(payload.answers, questions)
    if error:
        return Status(400, ErrorOut(detail=error))
    answers = _build_survey_answers(payload.answers, questions)
    user_name = (auth_user.display_name or auth_user.phone_number) if auth_user else None
    if survey.one_response_per_user and auth_user is not None:
        existing = SurveyResponse.objects.filter(survey=survey, user=auth_user).first()
        if existing:
            existing.answers = answers
            existing.save(update_fields=["answers"])
            return Status(200, _response_out(existing, user_name))
    response = SurveyResponse.objects.create(survey=survey, user=auth_user, answers=answers)
    return Status(201, _response_out(response, user_name))


@router.get(
    "/surveys/{survey_id}/tallies/",
    response={200: list[PollResultsOut], 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def get_survey_tallies(request, survey_id: UUID):
    try:
        survey = Survey.objects.prefetch_related("questions").get(id=survey_id)
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))
    poll_questions = [
        q for q in survey.questions.all() if q.field_type == SurveyQuestionType.DATETIME_POLL
    ]
    responses = list(survey.responses.select_related("user").all())
    tallies = [_tally_question(q, responses) for q in poll_questions]
    return Status(200, tallies)


@router.post(
    "/surveys/{survey_id}/finalize/",
    response={200: SurveyOut, 400: ErrorOut, 403: ErrorOut, 404: ErrorOut},
    auth=JWTAuth(),
)
def finalize_poll(request, survey_id: UUID, payload: FinalizePollIn):
    try:
        survey = (
            Survey.objects.select_related("linked_event", "created_by")
            .prefetch_related("questions")
            .get(id=survey_id)
        )
    except Survey.DoesNotExist:
        return Status(404, ErrorOut(detail="Survey not found."))

    event = survey.linked_event
    if not _has_finalize_permission(request, survey, event):
        return Status(403, ErrorOut(detail="Permission denied."))

    if hasattr(survey, "poll_result"):
        return Status(400, ErrorOut(detail="This poll has already been finalized."))

    poll_questions = [
        q for q in survey.questions.all() if q.field_type == SurveyQuestionType.DATETIME_POLL
    ]
    if not poll_questions:
        return Status(400, ErrorOut(detail="Survey has no datetime poll question."))

    winning_iso = payload.winning_datetime.isoformat()
    all_options = poll_questions[0].options or []
    if winning_iso not in all_options:
        return Status(400, ErrorOut(detail="Winning datetime is not one of the poll options."))

    DatetimePollResult.objects.create(
        survey=survey,
        winning_datetime=payload.winning_datetime,
        finalized_by=request.auth,
    )
    survey.is_active = False
    survey.save(update_fields=["is_active"])

    if event:
        event.start_datetime = payload.winning_datetime
        event.datetime_tbd = False
        event.save(update_fields=["start_datetime", "datetime_tbd"])

    survey.refresh_from_db()
    return Status(200, _survey_out(survey, include_questions=True, requesting_user=request.auth))
