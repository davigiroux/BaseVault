import { useBalance } from 'wagmi'
import { useAccount } from 'wagmi'
import type { Address } from 'viem'
import { isETH } from '../lib/tokens'

export function useWalletBalance(asset: Address) {
  const { address } = useAccount()

  const { data, isLoading } = useBalance({
    address,
    // undefined = native ETH; token address = ERC-20
    token: isETH(asset) ? undefined : asset,
    query: { enabled: !!address },
  })

  return {
    balance: data?.value ?? 0n,
    decimals: data?.decimals ?? 18,
    formatted: data?.formatted ?? '0',
    symbol: data?.symbol ?? '',
    isLoading,
  }
}
