/**
 * Lỗi nghiệp vụ theo hợp đồng API: luôn có `code` ổn định để client xử lý.
 * `message` chỉ dùng cho log và không hiển thị trực tiếp cho người dùng.
 */
export type ApiErrorCode =
  | 'VALIDATION_FAILED'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'RULE_VIOLATION'
  | 'SYNC_CONFLICT'
  | 'PLAN_LIMIT'
  | 'QUOTA_EXCEEDED'
  | 'RATE_LIMITED'
  | 'INTERNAL';

const STATUS: Record<ApiErrorCode, number> = {
  VALIDATION_FAILED: 400,
  UNAUTHENTICATED: 401,
  FORBIDDEN: 403,
  PLAN_LIMIT: 403,
  QUOTA_EXCEEDED: 403,
  NOT_FOUND: 404,
  SYNC_CONFLICT: 409,
  RULE_VIOLATION: 422,
  RATE_LIMITED: 429,
  INTERNAL: 500,
};

export class ApiError extends Error {
  readonly code: ApiErrorCode;
  readonly status: number;
  readonly field?: string;
  readonly details?: Record<string, unknown>;

  constructor(
    code: ApiErrorCode,
    message: string,
    options: { field?: string; details?: Record<string, unknown> } = {},
  ) {
    super(message);
    this.code = code;
    this.status = STATUS[code];
    this.field = options.field;
    this.details = options.details;
  }

  toBody(): { error: Record<string, unknown> } {
    return {
      error: {
        code: this.code,
        message: this.message,
        ...(this.field ? { field: this.field } : {}),
        ...(this.details ? { details: this.details } : {}),
      },
    };
  }
}
