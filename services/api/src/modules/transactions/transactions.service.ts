import { Inject, Injectable } from '@nestjs/common';

import { DATABASE, type Database } from '../../common/db/database.js';
import { ApiError } from '../../common/errors/api-error.js';
import type {
  CreateTransactionDto,
  ListTransactionsQuery,
  UpdateTransactionDto,
} from './transaction.dto.js';

export interface TransactionRow {
  id: string;
  wallet_id: string;
  category_id: string | null;
  type: string;
  amount: string | number;
  to_wallet_id: string | null;
  note: string | null;
  occurred_at: Date | string;
  occurred_on: string;
  source: string;
  payment_method: string | null;
  income_source: string | null;
  receipt_mime: string | null;
  receipt_data?: Buffer | null;
  receipt_base64?: string | null;
  /** Danh sách chỉ báo có hóa đơn; ảnh thật lấy ở `GET /v1/transactions/:id`. */
  has_receipt?: boolean;
  rev: number;
  created_at: Date | string;
  updated_at: Date | string;
  deleted_at: Date | string | null;
}

const SELECT_COLUMNS = `id, wallet_id, category_id, type, amount, to_wallet_id,
       note, occurred_at, occurred_on, source, payment_method, income_source,
       receipt_mime, receipt_data, rev, created_at, updated_at, deleted_at`;

@Injectable()
export class TransactionsService {
  constructor(@Inject(DATABASE) private readonly db: Database) {}

  /**
   * Danh sách theo cursor `occurred_at` giảm dần.
   * `occurred_on` do trigger DB sinh theo giờ Việt Nam, client không gửi.
   */
  async list(
    userId: string,
    query: ListTransactionsQuery,
  ): Promise<TransactionRow[]> {
    const limit = query.limit ?? 50;
    const params: unknown[] = [userId];
    const filters = ['user_id = $1'];

    if (!query.include_deleted) {
      filters.push('deleted_at IS NULL');
    }
    if (query.type) {
      params.push(query.type);
      filters.push(`type = $${params.length}`);
    }
    if (query.before) {
      params.push(query.before);
      filters.push(`occurred_at < $${params.length}`);
    }
    params.push(limit);

    const rows = await this.db.query<TransactionRow>(
      `SELECT ${SELECT_COLUMNS}
         FROM transactions
        WHERE ${filters.join(' AND ')}
        ORDER BY occurred_at DESC, id DESC
        LIMIT $${params.length}`,
      params,
    );
    // 50 dòng × ảnh hóa đơn 512KB là gần 25MB mỗi lần mở tab Giao dịch.
    // Danh sách chỉ nói có ảnh hay không; ảnh lấy riêng khi mở chi tiết.
    return rows.map((row) => toListRow(toTransaction(row)));
  }

  async findOne(userId: string, id: string): Promise<TransactionRow> {
    const row = await this.findById(userId, id);
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
    return row;
  }

  async create(
    userId: string,
    dto: CreateTransactionDto,
  ): Promise<TransactionRow> {
    if (dto.type === 'transfer' && !dto.to_wallet_id) {
      throw new ApiError(
        'RULE_VIOLATION',
        'Chuyển ví phải có ví nhận',
        { field: 'to_wallet_id' },
      );
    }
    if (dto.type === 'transfer' && dto.to_wallet_id === dto.wallet_id) {
      throw new ApiError('RULE_VIOLATION', 'Ví nhận phải khác ví gửi', {
        field: 'to_wallet_id',
      });
    }
    if (dto.category_id) {
      const category = await this.db.one<{ id: string }>(
        `SELECT id FROM categories
          WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
        [dto.category_id, userId],
      );
      if (!category) {
        throw new ApiError('NOT_FOUND', 'Danh mục không tồn tại', {
          field: 'category_id',
        });
      }
    }
    const receipt = parseReceipt(dto.receipt_base64, dto.receipt_mime);

    // Client sinh id: gửi lại cùng id phải idempotent, không tạo bản ghi trùng.
    const existing = await this.db.one<{ id: string; user_id: string }>(
      `SELECT id, user_id FROM transactions WHERE id = $1`,
      [dto.id],
    );
    if (existing) {
      if (existing.user_id !== userId) {
        throw new ApiError('FORBIDDEN', 'Giao dịch thuộc người dùng khác');
      }
      const row = await this.findById(userId, dto.id);
      if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
      return row;
    }

    await this.assertWallet(userId, dto.wallet_id, 'wallet_id');
    if (dto.to_wallet_id) {
      await this.assertWallet(userId, dto.to_wallet_id, 'to_wallet_id');
    }

    const row = await this.db.one<TransactionRow>(
      `INSERT INTO transactions
         (id, user_id, wallet_id, category_id, type, amount, to_wallet_id,
          note, occurred_at, source, payment_method, income_source,
          receipt_mime, receipt_data)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)
       RETURNING ${SELECT_COLUMNS}`,
      [
        dto.id,
        userId,
        dto.wallet_id,
        dto.category_id ?? null,
        dto.type,
        dto.amount,
        dto.to_wallet_id ?? null,
        dto.note ?? null,
        dto.occurred_at,
        dto.source ?? 'manual',
        dto.payment_method ?? null,
        dto.income_source?.trim() || null,
        receipt.mime,
        receipt.data,
      ],
    );
    if (!row) throw new ApiError('INTERNAL', 'Không tạo được giao dịch');
    return toTransaction(row);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateTransactionDto,
  ): Promise<TransactionRow> {
    const current = await this.findById(userId, id, true);
    if (!current) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
    if (dto.rev !== current.rev + 1) {
      throw new ApiError('SYNC_CONFLICT', 'Phiên bản không khớp', {
        details: { server_rev: current.rev, server_data: current },
      });
    }
    if (dto.category_id) {
      const category = await this.db.one<{ id: string }>(
        `SELECT id FROM categories
          WHERE id = $1 AND (user_id IS NULL OR user_id = $2) AND deleted_at IS NULL`,
        [dto.category_id, userId],
      );
      if (!category) {
        throw new ApiError('NOT_FOUND', 'Danh mục không tồn tại', {
          field: 'category_id',
        });
      }
    }

    // Ví/loại có thể đổi: ghi nhầm ví hay ghi Chi tiêu thành Thu nhập đều là
    // chuyện thật, bắt xóa rồi tạo lại là mất `created_at` và `rev`.
    const nextWalletId = dto.wallet_id ?? current.wallet_id;
    const nextType = dto.type ?? current.type;
    if (dto.wallet_id && dto.wallet_id !== current.wallet_id) {
      await this.assertWallet(userId, dto.wallet_id, 'wallet_id');
    }
    const nextToWalletId =
      nextType === 'transfer'
        ? (dto.to_wallet_id ?? current.to_wallet_id)
        : null; // đổi khỏi transfer thì ví nhận không còn nghĩa, bỏ luôn
    if (nextType === 'transfer') {
      if (!nextToWalletId) {
        throw new ApiError('RULE_VIOLATION', 'Chuyển ví phải có ví nhận', {
          field: 'to_wallet_id',
        });
      }
      if (nextToWalletId === nextWalletId) {
        throw new ApiError('RULE_VIOLATION', 'Ví nhận phải khác ví gửi', {
          field: 'to_wallet_id',
        });
      }
      if (dto.to_wallet_id) {
        await this.assertWallet(userId, dto.to_wallet_id, 'to_wallet_id');
      }
    }

    const receipt = parseReceipt(dto.receipt_base64, dto.receipt_mime);
    const removeReceipt = dto.remove_receipt === true;
    if (removeReceipt && receipt.data) {
      throw new ApiError('RULE_VIOLATION', 'Không thể vừa xóa vừa tải hóa đơn mới', {
        field: 'receipt_base64',
      });
    }

    // `undefined` = không gửi = giữ nguyên; `null` = gửi rõ ràng = xóa trắng.
    // COALESCE không phân biệt được hai thứ này nên phải quyết định ở đây.
    const nextPaymentMethod =
      dto.payment_method === undefined ? current.payment_method : dto.payment_method;
    const nextIncomeSource =
      dto.income_source === undefined
        ? current.income_source
        : dto.income_source?.trim() || null;

    const row = await this.db.one<TransactionRow>(
      `UPDATE transactions
          SET amount = COALESCE($3, amount),
              category_id = COALESCE($4, category_id),
              note = COALESCE($5, note),
              occurred_at = COALESCE($6, occurred_at),
              deleted_at = COALESCE($7, deleted_at),
              wallet_id = $8,
              type = $9,
              to_wallet_id = $10,
              payment_method = $11,
              income_source = $12,
              receipt_mime = CASE WHEN $13 THEN NULL WHEN $14::text IS NOT NULL THEN $14 ELSE receipt_mime END,
              receipt_data = CASE WHEN $13 THEN NULL WHEN $15::bytea IS NOT NULL THEN $15 ELSE receipt_data END,
              rev = rev + 1
        WHERE id = $1 AND user_id = $2
        RETURNING ${SELECT_COLUMNS}`,
      [
        id,
        userId,
        dto.amount ?? null,
        dto.category_id ?? null,
        dto.note ?? null,
        dto.occurred_at ?? null,
        dto.deleted_at ?? null,
        nextWalletId,
        nextType,
        nextToWalletId,
        nextPaymentMethod,
        nextIncomeSource,
        removeReceipt,
        receipt.mime,
        receipt.data,
      ],
    );
    if (!row) throw new ApiError('NOT_FOUND', 'Không tìm thấy giao dịch');
    return toTransaction(row);
  }

  private async assertWallet(
    userId: string,
    walletId: string,
    field: string,
  ): Promise<void> {
    const wallet = await this.db.one<{ id: string }>(
      `SELECT id FROM wallets
        WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL`,
      [walletId, userId],
    );
    if (!wallet) {
      throw new ApiError('NOT_FOUND', 'Ví không tồn tại', { field });
    }
  }

  private async findById(
    userId: string,
    id: string,
    includeDeleted = false,
  ): Promise<TransactionRow | null> {
    const row = await this.db.one<TransactionRow>(
      `SELECT ${SELECT_COLUMNS}
         FROM transactions
        WHERE id = $1 AND user_id = $2 ${includeDeleted ? '' : 'AND deleted_at IS NULL'}`,
      [id, userId],
    );
    return row ? toTransaction(row) : null;
  }
}

function toTransaction(row: TransactionRow): TransactionRow {
  const receipt =
    row.receipt_data && row.receipt_mime
      ? Buffer.from(row.receipt_data).toString('base64')
      : null;
  return {
    ...row,
    amount: Number(row.amount),
    occurred_at: toIso(row.occurred_at),
    created_at: toIso(row.created_at),
    updated_at: toIso(row.updated_at),
    deleted_at: row.deleted_at ? toIso(row.deleted_at) : null,
    payment_method: row.payment_method ?? null,
    income_source: row.income_source ?? null,
    receipt_mime: row.receipt_mime ?? null,
    receipt_base64: receipt,
    has_receipt: row.receipt_mime !== null,
    receipt_data: undefined,
  };
}

/** Bỏ bytes ảnh, giữ cờ `has_receipt` cho danh sách. */
function toListRow(row: TransactionRow): TransactionRow {
  return {
    ...row,
    has_receipt: row.receipt_mime !== null,
    receipt_base64: null,
  };
}

const RECEIPT_MAX_BYTES = 512 * 1024;

/** `Buffer.from(..., 'base64')` không ném lỗi: chuỗi rác chỉ bị cắt ký tự lạ,
 * nên kiểm chữ ký tệp mới biết đúng là ảnh. */
function sniffImageMime(data: Buffer): string | null {
  if (data.length >= 3 && data[0] === 0xff && data[1] === 0xd8 && data[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    data.length >= 8 &&
    data[0] === 0x89 &&
    data[1] === 0x50 &&
    data[2] === 0x4e &&
    data[3] === 0x47
  ) {
    return 'image/png';
  }
  if (
    data.length >= 12 &&
    data.subarray(0, 4).toString('latin1') === 'RIFF' &&
    data.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  return null;
}

function parseReceipt(
  receiptBase64?: string,
  receiptMime?: string,
): { data: Buffer | null; mime: string | null } {
  if (!receiptBase64 && !receiptMime) return { data: null, mime: null };
  if (!receiptBase64 || !receiptMime) {
    throw new ApiError('RULE_VIOLATION', 'Hóa đơn cần cả ảnh và loại ảnh', {
      field: 'receipt_base64',
    });
  }
  const data = Buffer.from(receiptBase64, 'base64');
  if (data.length === 0 || data.length > RECEIPT_MAX_BYTES) {
    throw new ApiError('RULE_VIOLATION', 'Ảnh hóa đơn tối đa 512KB', {
      field: 'receipt_base64',
    });
  }
  const sniffed = sniffImageMime(data);
  if (sniffed === null) {
    throw new ApiError('RULE_VIOLATION', 'Tệp đính kèm không phải ảnh JPEG/PNG/WebP', {
      field: 'receipt_base64',
    });
  }
  if (sniffed !== receiptMime) {
    throw new ApiError('RULE_VIOLATION', `Ảnh là ${sniffed} nhưng khai báo ${receiptMime}`, {
      field: 'receipt_mime',
    });
  }
  return { data, mime: receiptMime };
}

function toIso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}
