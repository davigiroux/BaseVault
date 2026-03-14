import type { Address } from 'viem'
import { useWithdraw } from '../hooks/useWithdraw'
import { formatCountdown } from '../lib/format'
import { getTokenMeta } from '../lib/tokens'

type WithdrawButtonProps = {
  vaultId: bigint
  asset: Address
  isLocked: boolean
  secondsRemaining: number
  onSuccess: () => void
}

export function WithdrawButton({
  vaultId,
  asset,
  isLocked,
  secondsRemaining,
  onSuccess,
}: WithdrawButtonProps) {
  const { withdraw, isPending, isConfirming, isSuccess, error, reset } =
    useWithdraw()
  const symbol = getTokenMeta(asset).symbol
  const isProcessing = isPending || isConfirming

  if (isSuccess) {
    return (
      <div className="rounded-lg border border-vault-success/20 bg-vault-success/5 p-4 text-center">
        <p className="text-sm font-medium text-vault-success">
          Withdrawal complete
        </p>
        <p className="mt-0.5 text-xs text-vault-muted">
          {symbol} returned to your wallet.
        </p>
        <button
          onClick={reset}
          className="mt-3 font-mono text-xs text-vault-muted underline decoration-vault-border underline-offset-4 transition-colors hover:text-vault-text"
        >
          Done
        </button>
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <button
        onClick={() => withdraw(vaultId).then(onSuccess)}
        disabled={isLocked || isProcessing}
        className={`w-full rounded-lg border px-4 py-2.5 font-mono text-sm font-medium transition-all active:scale-[0.98] disabled:active:scale-100 ${
          isLocked
            ? 'cursor-not-allowed border-vault-border bg-vault-surface/50 text-vault-muted'
            : 'border-vault-success/30 bg-vault-success/5 text-vault-success hover:border-vault-success/50 hover:bg-vault-success/10 disabled:cursor-not-allowed disabled:opacity-60'
        }`}
      >
        {isPending
          ? 'Confirm in wallet...'
          : isConfirming
            ? 'Confirming...'
            : isLocked
              ? `Locked — ${formatCountdown(secondsRemaining)}`
              : `Withdraw ${symbol}`}
      </button>

      {error && (
        <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-3 py-2">
          <p className="text-xs text-vault-danger">{error}</p>
        </div>
      )}
    </div>
  )
}
