import json
import logging

from config.logging_config import JsonFormatter, SensitiveDataFilter


class TestJsonFormatter:
    def test_format_outputs_valid_json_with_required_fields(self):
        formatter = JsonFormatter()
        record = logging.LogRecord(
            name="pda.test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Test message",
            args=None,
            exc_info=None,
        )
        output = formatter.format(record)
        parsed = json.loads(output)
        assert parsed["level"] == "INFO"
        assert parsed["logger"] == "pda.test"
        assert parsed["message"] == "Test message"
        assert "timestamp" in parsed

    def test_format_includes_extra_fields(self):
        formatter = JsonFormatter()
        record = logging.LogRecord(
            name="pda.test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Request completed",
            args=None,
            exc_info=None,
        )
        record.method = "GET"  # type: ignore[attr-defined]
        record.path = "/api/test/"  # type: ignore[attr-defined]
        output = formatter.format(record)
        parsed = json.loads(output)
        assert parsed["method"] == "GET"
        assert parsed["path"] == "/api/test/"

    def test_format_handles_exception_info(self):
        formatter = JsonFormatter()
        try:
            raise ValueError("test error")
        except ValueError:
            import sys

            exc_info = sys.exc_info()

        record = logging.LogRecord(
            name="pda.test",
            level=logging.ERROR,
            pathname="test.py",
            lineno=1,
            msg="An error occurred",
            args=None,
            exc_info=exc_info,
        )
        output = formatter.format(record)
        parsed = json.loads(output)
        assert "exception" in parsed
        assert "ValueError: test error" in parsed["exception"]


class TestSensitiveDataFilter:
    def test_redacts_password_values(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="password=secret123",
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert "secret123" not in record.msg
        assert "[REDACTED]" in record.msg

    def test_redacts_token_values(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="token=eyJhbGciOiJIUzI1NiJ9.payload.sig",
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert "eyJhbGci" not in record.msg
        assert "[REDACTED]" in record.msg

    def test_redacts_e164_phone_numbers(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="User logged in: +15551234567",
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert "+15551234567" not in record.msg
        assert "[REDACTED]" in record.msg

    def test_redacts_phone_number_field(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg='phone_number="+15551234567"',
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert "+15551234567" not in record.msg

    def test_passes_clean_messages_through(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Join request submitted by Alice",
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert record.msg == "Join request submitted by Alice"

    def test_redacts_authorization_header(self):
        f = SensitiveDataFilter()
        record = logging.LogRecord(
            name="test",
            level=logging.INFO,
            pathname="test.py",
            lineno=1,
            msg="Authorization: Bearer eyJtoken123",
            args=None,
            exc_info=None,
        )
        f.filter(record)
        assert "eyJtoken123" not in record.msg
        assert "[REDACTED]" in record.msg
