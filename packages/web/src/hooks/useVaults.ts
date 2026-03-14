import { useReadContract } from 'wagmi'
import { useAccount } from 'wagmi'
import { VAULT_V2_ABI, VAULT_V2_ADDRESS, type Vault } from '../lib/contract'

export function useVaults() {
  const { address } = useAccount()

  const { data, isLoading, error, refetch } = useReadContract({
    address: VAULT_V2_ADDRESS!,
    abi: VAULT_V2_ABI,
    functionName: 'getVaults',
    args: [address!],
    query: { enabled: !!address && !!VAULT_V2_ADDRESS },
  })

  const activeVaults: Vault[] =
    ((data as Vault[] | undefined) ?? []).filter((v) => v.principal > 0n)

  return {
    vaults: activeVaults,
    isLoading,
    error: error as Error | null,
    refetch,
  }
}
