import { useState, useCallback } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { zeroAddress } from 'viem'
import type { Address } from 'viem'
import { VAULT_V2_ABI, VAULT_V2_ADDRESS } from '../lib/contract'
import { parseVaultError } from '../lib/errors'

export function useDeposit() {
  const [error, setError] = useState<string | null>(null)
  const {
    writeContractAsync,
    data: txHash,
    isPending,
    reset: resetWrite,
  } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash })

  const deposit = useCallback(
    async (asset: Address, amount: bigint, lockDurationSeconds: bigint) => {
      if (!VAULT_V2_ADDRESS) return
      setError(null)
      const isNative = asset === zeroAddress
      try {
        await writeContractAsync({
          address: VAULT_V2_ADDRESS,
          abi: VAULT_V2_ABI,
          functionName: 'deposit',
          args: [asset, isNative ? 0n : amount, lockDurationSeconds],
          value: isNative ? amount : 0n,
        })
      } catch (err) {
        setError(parseVaultError(err))
      }
    },
    [writeContractAsync]
  )

  const reset = useCallback(() => {
    setError(null)
    resetWrite()
  }, [resetWrite])

  return { deposit, isPending, isConfirming, isSuccess, error, reset }
}
