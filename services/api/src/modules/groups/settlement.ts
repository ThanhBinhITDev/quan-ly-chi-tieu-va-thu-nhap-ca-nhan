/**
 * Ghép người nợ nhiều nhất với người được nhận nhiều nhất cho đến khi
 * tất cả về 0. Đây là gợi ý chuyển tiền tối thiểu (hợp đồng 8.4).
 * Server tính, client không tự tính.
 */
export interface NetBalance {
  user_id: string;
  net: number;
}

export interface Settlement {
  from: string;
  to: string;
  amount: number;
}

export function minimizeSettlements(balances: NetBalance[]): Settlement[] {
  const debtors = balances
    .filter((b) => b.net < 0)
    .map((b) => ({ id: b.user_id, left: -b.net }))
    .sort((a, b) => b.left - a.left);
  const creditors = balances
    .filter((b) => b.net > 0)
    .map((b) => ({ id: b.user_id, left: b.net }))
    .sort((a, b) => b.left - a.left);

  const settlements: Settlement[] = [];
  let i = 0;
  let j = 0;
  while (i < debtors.length && j < creditors.length) {
    const amount = Math.min(debtors[i].left, creditors[j].left);
    if (amount > 0) {
      settlements.push({
        from: debtors[i].id,
        to: creditors[j].id,
        amount,
      });
    }
    debtors[i].left -= amount;
    creditors[j].left -= amount;
    if (debtors[i].left === 0) i += 1;
    if (creditors[j].left === 0) j += 1;
  }
  return settlements;
}
