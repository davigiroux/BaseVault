import { describe, it, expect } from 'vitest'
import { base, baseSepolia } from 'wagmi/chains'
import { getExplorerUrl, getAddressUrl, getTxUrl } from '../chain'

describe('getExplorerUrl', () => {
  it('returns sepolia basescan for Base Sepolia', () => {
    expect(getExplorerUrl(baseSepolia.id)).toBe('https://sepolia.basescan.org')
  })

  it('returns mainnet basescan for Base', () => {
    expect(getExplorerUrl(base.id)).toBe('https://basescan.org')
  })

  it('falls back to sepolia for unknown chain', () => {
    expect(getExplorerUrl(99999)).toBe('https://sepolia.basescan.org')
  })
})

describe('getAddressUrl', () => {
  it('builds correct address URL for Base Sepolia', () => {
    expect(getAddressUrl(baseSepolia.id, '0xabc')).toBe(
      'https://sepolia.basescan.org/address/0xabc',
    )
  })

  it('builds correct address URL for Base mainnet', () => {
    expect(getAddressUrl(base.id, '0xdef')).toBe(
      'https://basescan.org/address/0xdef',
    )
  })
})

describe('getTxUrl', () => {
  it('builds correct tx URL', () => {
    expect(getTxUrl(baseSepolia.id, '0x123')).toBe(
      'https://sepolia.basescan.org/tx/0x123',
    )
  })
})
