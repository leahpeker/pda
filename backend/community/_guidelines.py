"""Guidelines and FAQ endpoints."""

from datetime import datetime

from ninja import Router
from ninja.responses import Status
from ninja_jwt.authentication import JWTAuth
from pydantic import BaseModel
from users.permissions import PermissionKey

from community._shared import ErrorOut
from community.models import FAQ, CommunityGuidelines

router = Router()


class GuidelinesOut(BaseModel):
    content: str
    updated_at: datetime


class GuidelinesPatchIn(BaseModel):
    content: str


@router.get("/guidelines/", response={200: GuidelinesOut}, auth=JWTAuth())
def get_guidelines(request):
    g = CommunityGuidelines.get()
    return Status(200, GuidelinesOut(content=g.content, updated_at=g.updated_at))


@router.patch("/guidelines/", response={200: GuidelinesOut, 403: ErrorOut}, auth=JWTAuth())
def update_guidelines(request, payload: GuidelinesPatchIn):
    if not request.auth.has_permission(PermissionKey.EDIT_GUIDELINES):
        return Status(403, ErrorOut(detail="Permission denied."))
    g = CommunityGuidelines.get()
    g.content = payload.content
    g.save()
    return Status(200, GuidelinesOut(content=g.content, updated_at=g.updated_at))


@router.get("/faq/", response={200: GuidelinesOut}, auth=None)
def get_faq(request):
    f = FAQ.get()
    return Status(200, GuidelinesOut(content=f.content, updated_at=f.updated_at))


@router.patch("/faq/", response={200: GuidelinesOut, 403: ErrorOut}, auth=JWTAuth())
def update_faq(request, payload: GuidelinesPatchIn):
    if not request.auth.has_permission(PermissionKey.EDIT_FAQ):
        return Status(403, ErrorOut(detail="Permission denied."))
    f = FAQ.get()
    f.content = payload.content
    f.save()
    return Status(200, GuidelinesOut(content=f.content, updated_at=f.updated_at))
