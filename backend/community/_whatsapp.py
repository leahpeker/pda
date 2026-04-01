"""WhatsApp configuration endpoints."""

from django.conf import settings
from ninja import Router
from ninja.responses import Status
from ninja_jwt.authentication import JWTAuth
from pydantic import BaseModel
from users.permissions import PermissionKey

from community._shared import ErrorOut
from community.models import WhatsAppConfig

router = Router()


class WhatsAppConfigOut(BaseModel):
    bot_url: str
    group_id: str
    has_secret: bool  # Don't expose the secret value, just whether it's set


class WhatsAppConfigPatchIn(BaseModel):
    bot_url: str | None = None
    bot_secret: str | None = None
    group_id: str | None = None


class WhatsAppStatusOut(BaseModel):
    connected: bool


@router.get(
    "/whatsapp/config/",
    response={200: WhatsAppConfigOut, 403: ErrorOut},
    auth=JWTAuth(),
)
def get_whatsapp_config(request):
    if not request.auth.has_permission(PermissionKey.MANAGE_WHATSAPP):
        return Status(403, ErrorOut(detail="Permission denied."))
    config = WhatsAppConfig.get()
    return Status(
        200,
        WhatsAppConfigOut(
            bot_url=config.bot_url,
            group_id=config.group_id,
            has_secret=bool(config.bot_secret),
        ),
    )


@router.patch(
    "/whatsapp/config/",
    response={200: WhatsAppConfigOut, 403: ErrorOut},
    auth=JWTAuth(),
)
def update_whatsapp_config(request, payload: WhatsAppConfigPatchIn):
    if not request.auth.has_permission(PermissionKey.MANAGE_WHATSAPP):
        return Status(403, ErrorOut(detail="Permission denied."))
    config = WhatsAppConfig.get()
    if payload.bot_url is not None:
        config.bot_url = payload.bot_url
    if payload.bot_secret is not None:
        config.bot_secret = payload.bot_secret
    if payload.group_id is not None:
        config.group_id = payload.group_id
    config.save()
    return Status(
        200,
        WhatsAppConfigOut(
            bot_url=config.bot_url,
            group_id=config.group_id,
            has_secret=bool(config.bot_secret),
        ),
    )


@router.get(
    "/whatsapp/status/",
    response={200: WhatsAppStatusOut, 403: ErrorOut},
    auth=JWTAuth(),
)
def get_whatsapp_status(request):
    if not request.auth.has_permission(PermissionKey.MANAGE_WHATSAPP):
        return Status(403, ErrorOut(detail="Permission denied."))
    config = WhatsAppConfig.get()
    bot_url = config.bot_url or getattr(settings, "WHATSAPP_BOT_URL", "")
    if not bot_url:
        return Status(200, WhatsAppStatusOut(connected=False))
    try:
        import urllib.request as _urllib

        req = _urllib.Request(
            bot_url.rstrip("/") + "/status",
            headers={
                "X-Bot-Secret": config.bot_secret or getattr(settings, "WHATSAPP_BOT_SECRET", "")
            },
        )
        with _urllib.urlopen(req, timeout=5) as resp:
            import json as _json

            data = _json.loads(resp.read())
            return Status(200, WhatsAppStatusOut(connected=bool(data.get("connected"))))
    except Exception:
        return Status(200, WhatsAppStatusOut(connected=False))
