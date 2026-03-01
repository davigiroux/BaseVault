import { formatEther } from 'viem'

export function formatEthAmount(wei: bigint, decimals = 4): string {
  const eth = formatEther(wei)
  return `${parseFloat(eth).toFixed(decimals)} ETH`
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
