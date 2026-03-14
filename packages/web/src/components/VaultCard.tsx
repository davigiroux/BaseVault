import { useEffect, useState } from 'react'
import { useAccount } from 'wagmi'
import type { Vault } from '../lib/contract'
import { formatAssetAmount, formatCountdown, formatUnlockDate } from '../lib/format'
import { getTokenMeta } from '../lib/tokens'
import { useAaveAPY } from '../hooks/useAaveAPY'
import { YieldDisplay } from './YieldDisplay'
import { WithdrawButton } from './WithdrawButton'

type VaultCardProps = {
  vault: Vault
  onWithdrawSuccess: () => void
}

export function VaultCard({ vault, onWithdrawSuccess }: VaultCardProps) {
  const { address } = useAccount()
  const token = getTokenMeta(vault.asset)
  const { apy } = useAaveAPY(vault.asset)

  const [secondsRemaining, setSecondsRemaining] = useState(() =>
    Math.max(0, Number(vault.unlocksAt) - Math.floor(Date.now() / 1000))
  )
  const isLocked = secondsRemaining > 0

  useEffect(() => {
    const interval = setInterval(() => {
      setSecondsRemaining(
        Math.max(0, Number(vault.unlocksAt) - Math.floor(Date.now() / 1000))
      )
    }, 1000)
    return () => clearInterval(interval)
  }, [vault.unlocksAt])

  return (
    <div className="animate-fade-in rounded-lg border border-vault-border bg-vault-surface p-4 sm:p-5">
      {/* Header row */}
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <span className="rounded-md border border-vault-border bg-vault-bg px-2 py-0.5 font-mono text-xs text-vault-muted">
            #{Number(vault.id)}
          </span>
          <span className="font-mono text-sm font-semibold text-vault-text">
            {token.symbol}
          </span>
        </div>
        <div className="flex items-center gap-2">
          {vault.yielding && apy !== null && (
            <span className="font-mono text-[10px] text-vault-success/70">
              ~{apy.toFixed(2)}% APY
            </span>
          )}
          <span
            className={`rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wider ${
              isLocked
                ? 'bg-vault-accent/10 text-vault-accent'
                : 'bg-vault-success/10 text-vault-success'
            }`}
          >
            {isLocked ? 'Locked' : 'Unlocked'}
          </span>
        </div>
      </div>

      {/* Principal + yield */}
      <div className="mb-3 space-y-1">
        <p className="font-mono text-lg font-semibold text-vault-text">
          {formatAssetAmount(vault.principal, vault.asset)}
        </p>
        {address && <YieldDisplay userAddress={address} vault={vault} />}
      </div>

      {/* Lock info */}
      <div className="mb-4 space-y-1 text-xs text-vault-muted">
        <p>
          {isLocked
            ? `Unlocks in ${formatCountdown(secondsRemaining)}`
            : `Unlocked ${formatUnlockDate(vault.unlocksAt)}`}
        </p>
      </div>

      <WithdrawButton
        vaultId={vault.id}
        asset={vault.asset}
        isLocked={isLocked}
        secondsRemaining={secondsRemaining}
        onSuccess={onWithdrawSuccess}
      />
    </div>
  )
}
