import { useReadContracts } from 'wagmi'
import { VAULT_V2_ABI, VAULT_V2_ADDRESS } from '../lib/contract'
import {
  ETH_TOKEN,
  KNOWN_TOKENS,
  type TokenMeta,
} from '../lib/tokens'
import type { Address } from 'viem'

export function useWhitelistedAssets() {
  const knownAddresses = Object.keys(KNOWN_TOKENS) as Address[]

  const { data, isLoading } = useReadContracts({
    query: { enabled: !!VAULT_V2_ADDRESS },
    contracts: knownAddresses.map((addr) => ({
      address: VAULT_V2_ADDRESS!,
      abi: VAULT_V2_ABI,
      functionName: 'whitelistedAssets' as const,
      args: [addr] as const,
    })),
  })

  const tokens: TokenMeta[] = [ETH_TOKEN]

  data?.forEach((result, i) => {
    if (result.status === 'success' && result.result === true) {
      tokens.push(KNOWN_TOKENS[knownAddresses[i]])
    }
  })

  return { tokens, isLoading }
}
