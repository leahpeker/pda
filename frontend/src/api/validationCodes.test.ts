import { describe, expect, it } from 'vitest';
import {
  ValidationCode,
  messageForCode,
  messagesFromFieldErrors,
  type FieldError,
} from './validationCodes';

describe('messageForCode', () => {
  it('returns friendly copy for known event-form codes', () => {
    expect(
      messageForCode({
        code: ValidationCode.StartDatetimeRequiredUnlessTbd,
        field: 'start_datetime',
      }),
    ).toBe('pick a start time, or mark the time as tbd');
  });

  it('uses the field name for generic fallback codes', () => {
    expect(messageForCode({ code: ValidationCode.FieldRequired, field: 'title' })).toContain(
      'title',
    );
    expect(messageForCode({ code: ValidationCode.FieldInvalid, field: 'max_attendees' })).toContain(
      'max attendees',
    );
  });

  it('returns a safe fallback for unknown codes', () => {
    expect(messageForCode({ code: 'something_the_fe_doesnt_know', field: null })).toMatch(
      /double-check/i,
    );
  });
});

describe('messagesFromFieldErrors', () => {
  it('joins multiple distinct errors with a middle dot', () => {
    const errors: FieldError[] = [
      { code: ValidationCode.FieldRequired, field: 'title' },
      { code: ValidationCode.StartDatetimeRequiredUnlessTbd, field: 'start_datetime' },
    ];
    const out = messagesFromFieldErrors(errors);
    expect(out).toContain('title');
    expect(out).toContain('start time');
    expect(out).toContain(' · ');
  });

  it('deduplicates repeated messages', () => {
    const errors: FieldError[] = [
      { code: ValidationCode.UrlInvalid, field: 'whatsapp_link' },
      { code: ValidationCode.UrlInvalid, field: 'whatsapp_link' },
    ];
    const out = messagesFromFieldErrors(errors);
    // one message, no separator
    expect(out).toBe('enter a valid url');
  });
});
