import json
import logging
import re
from datetime import UTC, datetime

# Fields from LogRecord that are part of the standard schema (not extras).
_STANDARD_FIELDS = frozenset(logging.LogRecord("", 0, "", 0, "", (), None).__dict__)


class JsonFormatter(logging.Formatter):
    """Outputs log records as single-line JSON for Railway log aggregation."""

    def format(self, record: logging.LogRecord) -> str:
        entry: dict[str, object] = {
            "timestamp": datetime.fromtimestamp(record.created, tz=UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Include any extra fields added via `logger.info("msg", extra={...})`.
        for key, value in record.__dict__.items():
            if key not in _STANDARD_FIELDS and key not in entry:
                entry[key] = value

        if record.exc_info and record.exc_info[1] is not None:
            entry["exception"] = self.formatException(record.exc_info)

        return json.dumps(entry, default=str)


# Patterns that indicate sensitive data (case-insensitive key=value style).
# The .+ at the end captures the rest of the value including spaces (e.g. "Bearer <token>").
_SENSITIVE_KEY_RE = re.compile(
    r"(password|token|secret|authorization|phone_number|phone)\s*[=:]\s*.+",
    re.IGNORECASE,
)

# E.164 phone number pattern: + followed by 10-15 digits.
_E164_RE = re.compile(r"\+\d{10,15}")


class SensitiveDataFilter(logging.Filter):
    """Redacts sensitive data from log messages before they reach handlers."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = _SENSITIVE_KEY_RE.sub(
            lambda m: (
                m.group(0).split("=")[0].split(":")[0] + "=[REDACTED]"
                if "=" in m.group(0)
                else m.group(0).split(":")[0] + ": [REDACTED]"
            ),
            str(record.msg),
        )
        record.msg = _E164_RE.sub("[REDACTED]", record.msg)
        return True
