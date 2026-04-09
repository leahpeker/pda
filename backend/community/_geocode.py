"""Geocoding proxy — avoids direct browser calls to Photon (blocks COEP)."""

import httpx
from django.http import HttpRequest
from ninja import Router
from ninja_jwt.authentication import JWTAuth

from community._shared import ErrorOut

router = Router()

_PHOTON_URL = "https://photon.komoot.io/api/"


@router.get("/geocode/", auth=JWTAuth(), response={200: dict, 502: ErrorOut})
def geocode(request: HttpRequest, q: str, limit: int = 5):
    """Proxy geocoding requests to Photon, biased toward NYC."""
    try:
        resp = httpx.get(
            _PHOTON_URL,
            params={"q": q, "limit": limit, "lat": 40.7128, "lon": -74.006},  # bias toward NYC
            timeout=5.0,
        )
        resp.raise_for_status()
        return 200, resp.json()
    except Exception:
        return 502, {"detail": "geocoding service unavailable — try again"}
