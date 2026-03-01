import { useState, useCallback } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'
import { VAULT_ABI, VAULT_ADDRESS } from '../lib/contract'
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
    async (ethAmount: string, lockDurationSeconds: bigint) => {
      setError(null)
      try {
        await writeContractAsync({
          address: VAULT_ADDRESS,
          abi: VAULT_ABI,
          functionName: 'deposit',
          args: [lockDurationSeconds],
          value: parseEther(ethAmount),
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
