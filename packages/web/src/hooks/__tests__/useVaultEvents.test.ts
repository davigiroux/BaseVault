import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'

// Mock wagmi — useWatchContractEvent is a no-op in tests
vi.mock('wagmi', () => ({
  useWatchContractEvent: vi.fn(),
}))

// Mock viem's createPublicClient at module level
const mockGetBlockNumber = vi.fn<() => Promise<bigint>>()
const mockGetContractEvents = vi.fn<() => Promise<unknown[]>>()
const mockGetBlock = vi.fn<() => Promise<{ timestamp: bigint }>>()

vi.mock('viem', async () => {
  const actual = await vi.importActual('viem')
  return {
    ...actual,
    createPublicClient: () => ({
      getBlockNumber: mockGetBlockNumber,
      getContractEvents: mockGetContractEvents,
      getBlock: mockGetBlock,
    }),
  }
})

// Import after mocks are set up
const { useVaultEvents } = await import('../useVaultEvents')

function makeMockLog(
  overrides: {
    depositor?: string
    amount?: bigint
    unlocksAt?: bigint
    blockNumber?: bigint
    transactionHash?: string
    logIndex?: number
  } = {},
) {
  return {
    args: {
      depositor: overrides.depositor ?? '0x1234567890abcdef1234567890abcdef12345678',
      amount: overrides.amount ?? 100_000_000_000_000n,
      unlocksAt: overrides.unlocksAt ?? 1772006400n,
    },
    blockNumber: overrides.blockNumber ?? 38_270_000n,
    transactionHash:
      overrides.transactionHash ??
      '0xaaaa000000000000000000000000000000000000000000000000000000000000',
    logIndex: overrides.logIndex ?? 0,
  }
}

describe('useVaultEvents', () => {
  beforeEach(() => {
    vi.clearAllMocks()
    // Default: return empty arrays for any getContractEvents call
    // (pagination may trigger multiple chunk requests)
    mockGetContractEvents.mockResolvedValue([])
    mockGetBlock.mockResolvedValue({ timestamp: 1709251200n })
  })

  it('starts in loading state', () => {
    mockGetBlockNumber.mockReturnValue(new Promise(() => {})) // never resolves
    const { result } = renderHook(() => useVaultEvents())
    expect(result.current.isLoading).toBe(true)
    expect(result.current.events).toEqual([])
    expect(result.current.error).toBeNull()
  })

  it('fetches and returns events sorted newest-first', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)

    const oldLog = makeMockLog({ blockNumber: 38_261_000n, logIndex: 0 })
    const newLog = makeMockLog({ blockNumber: 38_269_000n, logIndex: 1 })

    mockGetContractEvents
      .mockResolvedValueOnce([oldLog, newLog]) // deposits
      .mockResolvedValueOnce([]) // withdrawals

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.events).toHaveLength(2)
    expect(result.current.events[0].blockNumber).toBe(38_269_000n)
    expect(result.current.events[1].blockNumber).toBe(38_261_000n)
  })

  it('sets error state on RPC failure', async () => {
    mockGetBlockNumber.mockRejectedValue(new Error('RPC down'))

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.error).toBe('Failed to load event history')
    expect(result.current.events).toEqual([])
  })

  it('caps events at MAX_EVENTS (20)', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)

    const logs = Array.from({ length: 25 }, (_, i) =>
      makeMockLog({ blockNumber: BigInt(38_261_000 + i), logIndex: i }),
    )

    mockGetContractEvents
      .mockResolvedValueOnce(logs) // deposits
      .mockResolvedValueOnce([]) // withdrawals

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.events).toHaveLength(20)
  })

  it('resolves timestamps from blocks', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)
    mockGetContractEvents
      .mockResolvedValueOnce([makeMockLog()])
      .mockResolvedValueOnce([])
    mockGetBlock.mockResolvedValue({ timestamp: 1709251200n })

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.events[0].timestamp).toBe(1709251200)
  })

  it('gracefully handles timestamp resolution failure', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)
    mockGetContractEvents
      .mockResolvedValueOnce([makeMockLog()])
      .mockResolvedValueOnce([])
    mockGetBlock.mockRejectedValue(new Error('getBlock failed'))

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    expect(result.current.events[0].timestamp).toBeNull()
  })

  it('parses deposit events correctly', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)
    mockGetContractEvents
      .mockResolvedValueOnce([
        makeMockLog({ amount: 500_000_000_000_000_000n, unlocksAt: 1772006400n }),
      ])
      .mockResolvedValueOnce([])

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const event = result.current.events[0]
    expect(event.type).toBe('deposit')
    expect(event.amount).toBe(500_000_000_000_000_000n)
    expect(event.unlocksAt).toBe(1772006400n)
  })

  it('parses withdrawal events correctly', async () => {
    mockGetBlockNumber.mockResolvedValue(38_270_000n)
    mockGetContractEvents
      .mockResolvedValueOnce([]) // deposits
      .mockResolvedValueOnce([makeMockLog({ amount: 1_000_000_000_000_000_000n })])

    const { result } = renderHook(() => useVaultEvents())

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false)
    })

    const event = result.current.events[0]
    expect(event.type).toBe('withdrawal')
    expect(event.unlocksAt).toBeUndefined()
  })
})
