import { useState, useEffect, useCallback, useRef } from 'react'
import { createPublicClient, http } from 'viem'
import { baseSepolia } from 'viem/chains'
import { useWatchContractEvent } from 'wagmi'
import { VAULT_ABI, VAULT_ADDRESS } from '../lib/contract'
import type { VaultEvent, VaultEventType } from '../lib/events'

const MAX_EVENTS = 20
const CHUNK_SIZE = 9_999n // eth_getLogs max range on public RPCs
const DEPLOY_BLOCK = 38_260_000n // BaseVault deployment on Base Sepolia

// Both Alchemy (free) and Base public RPC limit eth_getLogs range.
// Use public RPC (more generous) and paginate in chunks.
const logsClient = createPublicClient({
  chain: baseSepolia,
  transport: http('https://sepolia.base.org'),
})

type RawLog = {
  args: Record<string, unknown>
  transactionHash: `0x${string}` | null
  logIndex: number | null
  blockNumber: bigint | null
}

function parseLog(log: RawLog, type: VaultEventType): VaultEvent {
  const { args } = log
  return {
    id: `${log.transactionHash}-${log.logIndex}`,
    type,
    depositor: args.depositor as `0x${string}`,
    amount: args.amount as bigint,
    unlocksAt: type === 'deposit' ? (args.unlocksAt as bigint) : undefined,
    blockNumber: log.blockNumber ?? 0n,
    transactionHash: log.transactionHash ?? '0x',
    timestamp: null,
  }
}

export function useVaultEvents() {
  const [events, setEvents] = useState<VaultEvent[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const timestampCache = useRef<Map<bigint, number>>(new Map())

  const resolveTimestamps = useCallback(
    async (evts: VaultEvent[]): Promise<VaultEvent[]> => {
      const uncached = [...new Set(evts.map((e) => e.blockNumber))].filter(
        (b) => !timestampCache.current.has(b),
      )

      await Promise.all(
        uncached.map(async (blockNumber) => {
          try {
            const block = await logsClient.getBlock({ blockNumber })
            timestampCache.current.set(blockNumber, Number(block.timestamp))
          } catch {
            // timestamp stays null — graceful degradation
          }
        }),
      )

      return evts.map((e) => ({
        ...e,
        timestamp: timestampCache.current.get(e.blockNumber) ?? null,
      }))
    },
    [],
  )

  // Fetch historical events on mount
  useEffect(() => {
    let cancelled = false

    async function fetchHistory() {
      setIsLoading(true)
      setError(null)
      try {
        const currentBlock = await logsClient.getBlockNumber()
        const allEvents: VaultEvent[] = []

        // Paginate backward from current block to deployment block
        for (
          let to = currentBlock;
          to >= DEPLOY_BLOCK && allEvents.length < MAX_EVENTS;
          to -= CHUNK_SIZE + 1n
        ) {
          if (cancelled) return
          const from = to - CHUNK_SIZE < DEPLOY_BLOCK
            ? DEPLOY_BLOCK
            : to - CHUNK_SIZE

          const [deposits, withdrawals] = await Promise.all([
            logsClient.getContractEvents({
              address: VAULT_ADDRESS,
              abi: VAULT_ABI,
              eventName: 'VaultDeposited',
              fromBlock: from,
              toBlock: to,
            }),
            logsClient.getContractEvents({
              address: VAULT_ADDRESS,
              abi: VAULT_ABI,
              eventName: 'VaultWithdrawn',
              fromBlock: from,
              toBlock: to,
            }),
          ])

          allEvents.push(
            ...deposits.map((l) => parseLog(l as unknown as RawLog, 'deposit')),
            ...withdrawals.map(
              (l) => parseLog(l as unknown as RawLog, 'withdrawal'),
            ),
          )
        }

        if (cancelled) return

        const sorted = allEvents
          .sort((a, b) => Number(b.blockNumber - a.blockNumber))
          .slice(0, MAX_EVENTS)

        const withTimestamps = await resolveTimestamps(sorted)
        if (!cancelled) {
          setEvents(withTimestamps)
          setIsLoading(false)
        }
      } catch (err) {
        console.error('[useVaultEvents] fetchHistory failed:', err)
        if (!cancelled) {
          setError('Failed to load event history')
          setIsLoading(false)
        }
      }
    }

    fetchHistory()
    return () => {
      cancelled = true
    }
  }, [resolveTimestamps])

  // Subscribe to new deposit events
  useWatchContractEvent({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    eventName: 'VaultDeposited',
    onLogs(logs) {
      const parsed = logs.map((l) =>
        parseLog(l as unknown as RawLog, 'deposit'),
      )
      resolveTimestamps(parsed).then((withTs) => {
        setEvents((prev) => {
          const existingIds = new Set(prev.map((e) => e.id))
          const newEvents = withTs.filter((e) => !existingIds.has(e.id))
          return [...newEvents, ...prev].slice(0, MAX_EVENTS)
        })
      })
    },
  })

  // Subscribe to new withdrawal events
  useWatchContractEvent({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    eventName: 'VaultWithdrawn',
    onLogs(logs) {
      const parsed = logs.map((l) =>
        parseLog(l as unknown as RawLog, 'withdrawal'),
      )
      resolveTimestamps(parsed).then((withTs) => {
        setEvents((prev) => {
          const existingIds = new Set(prev.map((e) => e.id))
          const newEvents = withTs.filter((e) => !existingIds.has(e.id))
          return [...newEvents, ...prev].slice(0, MAX_EVENTS)
        })
      })
    },
  })

  return { events, isLoading, error }
}
