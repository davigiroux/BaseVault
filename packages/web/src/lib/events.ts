import type { Address, Hash } from 'viem'

export type VaultEventType = 'deposit' | 'withdrawal'

export type VaultEvent = {
  id: string // `${txHash}-${logIndex}` for dedup + React key
  type: VaultEventType
  depositor: Address
  amount: bigint
  unlocksAt?: bigint // only on deposits
  blockNumber: bigint
  transactionHash: Hash
  timestamp: number | null // unix seconds, null if block not yet resolved
}
