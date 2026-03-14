import type { Address } from 'viem'
import { useVaultYield } from '../hooks/useVaultYield'
import { formatAssetAmount } from '../lib/format'
import type { Vault } from '../lib/contract'

type YieldDisplayProps = {
  userAddress: Address
  vault: Vault
}

export function YieldDisplay({ userAddress, vault }: YieldDisplayProps) {
  const { yield: yieldAmount, isLoading } = useVaultYield(userAddress, vault.id)

  if (!vault.yielding || (yieldAmount === 0n && !isLoading)) return null

  return (
    <div className="flex items-center gap-1.5">
      <div className="h-1.5 w-1.5 rounded-full bg-vault-success animate-pulse" />
      <span className="font-mono text-xs text-vault-success">
        {isLoading
          ? '...'
          : `+${formatAssetAmount(yieldAmount, vault.asset)} yield`}
      </span>
    </div>
  )
}
