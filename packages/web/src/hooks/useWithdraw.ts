import { useState, useCallback } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { VAULT_ABI, VAULT_ADDRESS } from '../lib/contract'
import { parseVaultError } from '../lib/errors'

export function useWithdraw() {
  const [error, setError] = useState<string | null>(null)
  const {
    writeContractAsync,
    data: txHash,
    isPending,
    reset: resetWrite,
  } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash })

  const withdraw = useCallback(async () => {
    setError(null)
    try {
      await writeContractAsync({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: 'withdraw',
      })
    } catch (err) {
      setError(parseVaultError(err))
    }
  }, [writeContractAsync])

  const reset = useCallback(() => {
    setError(null)
    resetWrite()
  }, [resetWrite])

  return { withdraw, isPending, isConfirming, isSuccess, error, reset }
}
