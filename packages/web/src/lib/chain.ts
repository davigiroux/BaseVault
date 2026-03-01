import { base, baseSepolia } from 'wagmi/chains'

const EXPLORER_URLS: Record<number, string> = {
  [baseSepolia.id]: 'https://sepolia.basescan.org',
  [base.id]: 'https://basescan.org',
}

export function getExplorerUrl(chainId: number): string {
  return EXPLORER_URLS[chainId] ?? EXPLORER_URLS[baseSepolia.id]
}

export function getAddressUrl(chainId: number, address: string): string {
  return `${getExplorerUrl(chainId)}/address/${address}`
}

export function getTxUrl(chainId: number, hash: string): string {
  return `${getExplorerUrl(chainId)}/tx/${hash}`
}
