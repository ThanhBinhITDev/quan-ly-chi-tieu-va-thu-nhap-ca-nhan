/**
 * Truy vấn SQL tham số hoá. Không nối chuỗi để tránh SQL injection.
 * `query` trả về các dòng; `one` trả về dòng đầu hoặc null.
 */
export interface Database {
  query<T>(sql: string, params?: unknown[]): Promise<T[]>;
  one<T>(sql: string, params?: unknown[]): Promise<T | null>;
  /**
   * Chạy `fn` trong một transaction. Ném lỗi thì rollback toàn bộ.
   * Dùng cho nghiệp vụ nhiều bước như chia tiền nhóm.
   */
  transaction<T>(fn: (tx: Database) => Promise<T>): Promise<T>;
}

export const DATABASE = Symbol('DATABASE');
