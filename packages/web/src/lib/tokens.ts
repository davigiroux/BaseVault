import type { Address } from 'viem'

export type TokenMeta = {
  symbol: string
  decimals: number
  address: Address
  name: string
}

export const ETH_TOKEN: TokenMeta = {
  symbol: 'ETH',
  decimals: 18,
  address: '0x0000000000000000000000000000000000000000',
  name: 'Ether',
}

/** Known ERC-20s on Base Sepolia — extend when new tokens are whitelisted */
export const KNOWN_TOKENS: Record<string, TokenMeta> = {
  '0x036CbD53842c5426634e7929541eC2318f3dCF7e': {
    symbol: 'USDC',
    decimals: 6,
    address: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    name: 'USD Coin',
  },
  '0x4200000000000000000000000000000000000006': {
    symbol: 'WETH',
    decimals: 18,
    address: '0x4200000000000000000000000000000000000006',
    name: 'Wrapped Ether',
  },
}

export function isETH(asset: Address): boolean {
  return asset === '0x0000000000000000000000000000000000000000'
}

export function getTokenMeta(asset: Address): TokenMeta {
  if (isETH(asset)) return ETH_TOKEN
  return KNOWN_TOKENS[asset] ?? {
    symbol: '???',
    decimals: 18,
    address: asset,
    name: 'Unknown Token',
  }
}
