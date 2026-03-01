import { useEffect, useState } from 'react'
import { useAccount, useReadContract } from 'wagmi'
import { zeroAddress } from 'viem'
import { VAULT_ABI, VAULT_ADDRESS, type VaultDeposit } from '../lib/contract'

export function useVault() {
  const { address } = useAccount()
  const [secondsRemaining, setSecondsRemaining] = useState(0)

  const { data, isLoading, error, refetch } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'getDeposit',
    args: [address ?? zeroAddress],
    query: { enabled: !!address },
  })

  const deposit = data as VaultDeposit | undefined
  const hasDeposit = !!deposit && deposit.amount > 0n

  useEffect(() => {
    if (!hasDeposit || !deposit) {
      setSecondsRemaining(0)
      return
    }

    const compute = () =>
      Math.max(0, Number(deposit.unlocksAt) - Math.floor(Date.now() / 1000))

    setSecondsRemaining(compute())

    const id = setInterval(() => {
      const s = compute()
      setSecondsRemaining(s)
      if (s === 0) clearInterval(id)
    }, 1000)

    return () => clearInterval(id)
  }, [hasDeposit, deposit ? Number(deposit.unlocksAt) : 0])

  return {
    deposit,
    hasDeposit,
    isLocked: secondsRemaining > 0,
    secondsRemaining,
    isLoading,
    error: error as Error | null,
    refetch,
  }
}
