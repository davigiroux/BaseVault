import { formatEther, formatUnits } from 'viem'
import type { Address } from 'viem'
import { getTokenMeta, isETH } from './tokens'

export function formatEthAmount(wei: bigint, decimals = 4): string {
  const eth = formatEther(wei)
  return `${parseFloat(eth).toFixed(decimals)} ETH`
}

export function formatAssetAmount(
  wei: bigint,
  asset: Address,
  maxDecimals = 4
): string {
  const meta = getTokenMeta(asset)
  const formatted = isETH(asset)
    ? formatEther(wei)
    : formatUnits(wei, meta.decimals)
  return `${parseFloat(formatted).toFixed(maxDecimals)} ${meta.symbol}`
}

export function formatCountdown(secondsRemaining: number): string {
  if (secondsRemaining <= 0) return 'Unlocked'

  const d = Math.floor(secondsRemaining / 86400)
  const h = Math.floor((secondsRemaining % 86400) / 3600)
  const m = Math.floor((secondsRemaining % 3600) / 60)
  const s = secondsRemaining % 60

  const parts: string[] = []
  if (d > 0) parts.push(`${d}d`)
  if (h > 0) parts.push(`${h}h`)
  if (m > 0) parts.push(`${m}m`)
  parts.push(`${s}s`)

  return parts.join(' ')
}

export function formatUnlockDate(unixTimestamp: bigint): string {
  return new Date(Number(unixTimestamp) * 1000).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

export function truncateAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}

export function formatRelativeTime(unixSeconds: number): string {
  const diff = Math.floor(Date.now() / 1000) - unixSeconds
  if (diff < 60) return 'just now'
  if (diff < 3600) return `${Math.floor(diff / 60)}m ago`
  if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`
  return `${Math.floor(diff / 86400)}d ago`
}
