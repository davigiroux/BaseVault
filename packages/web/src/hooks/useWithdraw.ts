import { useState, useCallback } from 'react'
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { VAULT_V2_ABI, VAULT_V2_ADDRESS } from '../lib/contract'
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

  const withdraw = useCallback(async (vaultId: bigint) => {
    if (!VAULT_V2_ADDRESS) return
    setError(null)
    try {
      await writeContractAsync({
        address: VAULT_V2_ADDRESS,
        abi: VAULT_V2_ABI,
        functionName: 'withdraw',
        args: [vaultId],
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
