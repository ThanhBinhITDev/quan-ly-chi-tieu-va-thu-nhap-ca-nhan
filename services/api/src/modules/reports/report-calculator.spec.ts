import { describe, expect, it } from 'vitest';

import {
  dailyLimit,
  daysLeftInPeriod,
  percent,
  vietnamMonthRange,
} from './report-calculator.js';

describe('dailyLimit', () => {
  it('làm tròn xuống, không làm tròn gần', () => {
    expect(dailyLimit(1_150_000, 18)).toBe(63_888);
  });

  it('days_left = 1 vào ngày cuối kỳ', () => {
    expect(dailyLimit(300_000, 1)).toBe(300_000);
  });

  it('remaining âm thì trả nguyên số âm, không chia', () => {
    expect(dailyLimit(-50_000, 10)).toBe(-50_000);
  });

  it('remaining = 0 trả 0', () => {
    expect(dailyLimit(0, 10)).toBe(0);
  });

  it('days_left = 0 trả remaining', () => {
    expect(dailyLimit(120_000, 0)).toBe(120_000);
  });
});

describe('daysLeftInPeriod', () => {
  it('tính cả hôm nay', () => {
    const days = daysLeftInPeriod(
      new Date('2026-11-13T00:00:00Z'),
      new Date('2026-11-01T00:00:00Z'),
      new Date('2026-11-30T00:00:00Z'),
    );
    expect(days).toBe(18);
  });

  it('ngày cuối kỳ là 1', () => {
    expect(
      daysLeftInPeriod(
        new Date('2026-11-30T00:00:00Z'),
        new Date('2026-11-01T00:00:00Z'),
        new Date('2026-11-30T00:00:00Z'),
      ),
    ).toBe(1);
  });

  it('qua kỳ thì 0', () => {
    expect(
      daysLeftInPeriod(
        new Date('2026-12-02T00:00:00Z'),
        new Date('2026-11-01T00:00:00Z'),
        new Date('2026-11-30T00:00:00Z'),
      ),
    ).toBe(0);
  });
});

describe('vietnamMonthRange', () => {
  it('tháng 11 có 30 ngày', () => {
    expect(vietnamMonthRange(2026, 11)).toEqual({
      start: '2026-11-01',
      end: '2026-11-30',
    });
  });

  it('tháng 2 năm nhuận có 29 ngày', () => {
    expect(vietnamMonthRange(2028, 2).end).toBe('2028-02-29');
  });

  it('tháng 12 kết thúc 31/12', () => {
    expect(vietnamMonthRange(2026, 12).end).toBe('2026-12-31');
  });
});

describe('percent', () => {
  it('một chữ số thập phân', () => {
    expect(percent(1_850_000, 3_000_000)).toBe(61.7);
  });

  it('chia cho 0 trả 0', () => {
    expect(percent(100, 0)).toBe(0);
  });
});
