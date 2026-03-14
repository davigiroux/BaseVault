import { useState, useCallback } from 'react'
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useAccount } from 'wagmi'
import { erc20Abi, maxUint256, zeroAddress } from 'viem'
import type { Address } from 'viem'
import { VAULT_V2_ADDRESS } from '../lib/contract'
import { isETH } from '../lib/tokens'

export function useTokenApproval(token: Address | undefined, amount: bigint) {
  const { address } = useAccount()
  const [approvalError, setApprovalError] = useState<string | null>(null)
  const tokenIsETH = !token || isETH(token)

  const {
    data: allowance,
    refetch: refetchAllowance,
  } = useReadContract({
    address: token ?? zeroAddress,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address!, VAULT_V2_ADDRESS!],
    query: { enabled: !tokenIsETH && !!address && !!token && !!VAULT_V2_ADDRESS },
  })

  const needsApproval =
    !tokenIsETH && allowance !== undefined && (allowance as bigint) < amount

  const {
    writeContractAsync,
    data: txHash,
    isPending,
    reset: resetWrite,
  } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  })

  const approve = useCallback(async () => {
    if (tokenIsETH || !token || !VAULT_V2_ADDRESS) return
    setApprovalError(null)
    try {
      await writeContractAsync({
        address: token,
        abi: erc20Abi,
        functionName: 'approve',
        args: [VAULT_V2_ADDRESS!, maxUint256],
      })
      await refetchAllowance()
    } catch {
      setApprovalError('Approval failed. Please try again.')
    }
  }, [token, tokenIsETH, writeContractAsync, refetchAllowance])

  const reset = useCallback(() => {
    setApprovalError(null)
    resetWrite()
  }, [resetWrite])

  return {
    needsApproval,
    approve,
    isPending: isPending || isConfirming,
    isSuccess,
    error: approvalError,
    reset,
    allowance: allowance as bigint | undefined,
  }
}
