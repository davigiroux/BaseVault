import { useReadContract } from 'wagmi'
import type { Address } from 'viem'
import { VAULT_V2_ABI, VAULT_V2_ADDRESS } from '../lib/contract'

export function useVaultYield(
  userAddress: Address | undefined,
  vaultId: bigint
) {
  const { data, isLoading } = useReadContract({
    address: VAULT_V2_ADDRESS!,
    abi: VAULT_V2_ABI,
    functionName: 'totalYield',
    args: [userAddress!, vaultId],
    query: {
      enabled: !!userAddress && !!VAULT_V2_ADDRESS,
      refetchInterval: 30_000,
      staleTime: 25_000,
    },
  })

  return {
    yield: (data as bigint | undefined) ?? 0n,
    isLoading,
  }
}
