import { describe, it, expect, vi, afterEach } from 'vitest'
import {
  formatEthAmount,
  formatCountdown,
  formatUnlockDate,
  truncateAddress,
  formatRelativeTime,
} from '../format'

describe('formatEthAmount', () => {
  it('formats zero', () => {
    expect(formatEthAmount(0n)).toBe('0.0000 ETH')
  })

  it('formats small amounts', () => {
    expect(formatEthAmount(50_000_000_000_000n)).toBe('0.0001 ETH')
  })

  it('formats whole ETH', () => {
    expect(formatEthAmount(1_000_000_000_000_000_000n)).toBe('1.0000 ETH')
  })

  it('formats large amounts', () => {
    expect(formatEthAmount(123_456_000_000_000_000_000n)).toBe('123.4560 ETH')
  })

  it('respects custom decimals', () => {
    expect(formatEthAmount(1_500_000_000_000_000_000n, 2)).toBe('1.50 ETH')
  })
})

describe('formatCountdown', () => {
  it('returns Unlocked for zero', () => {
    expect(formatCountdown(0)).toBe('Unlocked')
  })

  it('returns Unlocked for negative', () => {
    expect(formatCountdown(-5)).toBe('Unlocked')
  })

  it('formats seconds only', () => {
    expect(formatCountdown(45)).toBe('45s')
  })

  it('formats minutes and seconds', () => {
    expect(formatCountdown(125)).toBe('2m 5s')
  })

  it('formats hours, minutes, seconds', () => {
    expect(formatCountdown(3661)).toBe('1h 1m 1s')
  })

  it('formats days, hours, minutes, seconds', () => {
    expect(formatCountdown(90061)).toBe('1d 1h 1m 1s')
  })

  it('omits zero parts', () => {
    expect(formatCountdown(86400)).toBe('1d 0s')
  })
})

describe('formatUnlockDate', () => {
  it('returns a formatted date string', () => {
    const result = formatUnlockDate(1772049600n)
    // Format: "Mon DD, YYYY" — exact date depends on timezone
    expect(result).toMatch(/\w{3} \d{1,2}, \d{4}/)
  })

  it('returns different output for different timestamps', () => {
    const a = formatUnlockDate(1772049600n)
    const b = formatUnlockDate(1772049600n + 86400n * 30n)
    expect(a).not.toBe(b)
  })
})

describe('truncateAddress', () => {
  it('truncates a standard address', () => {
    expect(truncateAddress('0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408')).toBe(
      '0xA428...d408',
    )
  })

  it('truncates the zero address', () => {
    expect(
      truncateAddress('0x0000000000000000000000000000000000000000'),
    ).toBe('0x0000...0000')
  })
})

describe('formatRelativeTime', () => {
  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('returns "just now" for < 60s ago', () => {
    const now = Math.floor(Date.now() / 1000)
    expect(formatRelativeTime(now - 30)).toBe('just now')
  })

  it('returns minutes ago', () => {
    const now = Math.floor(Date.now() / 1000)
    expect(formatRelativeTime(now - 300)).toBe('5m ago')
  })

  it('returns hours ago', () => {
    const now = Math.floor(Date.now() / 1000)
    expect(formatRelativeTime(now - 7200)).toBe('2h ago')
  })

  it('returns days ago', () => {
    const now = Math.floor(Date.now() / 1000)
    expect(formatRelativeTime(now - 172800)).toBe('2d ago')
  })
})
