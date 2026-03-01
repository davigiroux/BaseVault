import { useWithdraw } from '../hooks/useWithdraw'
import { useVault } from '../hooks/useVault'
import { formatCountdown } from '../lib/format'

export function WithdrawButton() {
  const { hasDeposit, isLocked, secondsRemaining, refetch } = useVault()
  const { withdraw, isPending, isConfirming, isSuccess, error, reset } =
    useWithdraw()

  const isProcessing = isPending || isConfirming

  if (!hasDeposit) return null

  async function handleWithdraw() {
    await withdraw()
    refetch()
  }

  if (isSuccess) {
    return (
      <div className="animate-fade-in rounded-lg border border-vault-success/20 bg-vault-success/5 p-6 text-center">
        <p className="text-sm font-medium text-vault-success">
          Withdrawal complete
        </p>
        <p className="mt-1 text-xs text-vault-muted">
          ETH has been returned to your wallet.
        </p>
        <button
          onClick={reset}
          className="mt-4 font-mono text-xs text-vault-muted underline decoration-vault-border underline-offset-4 transition-colors hover:text-vault-text"
        >
          Done
        </button>
      </div>
    )
  }

  const disabled = isLocked || isProcessing

  return (
    <div className="animate-fade-in space-y-3">
      <button
        onClick={handleWithdraw}
        disabled={disabled}
        className={`w-full rounded-lg border px-4 py-3 font-mono text-sm font-medium transition-all active:scale-[0.98] disabled:active:scale-100 ${
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
              : 'Withdraw ETH'}
      </button>

      {error && (
        <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-4 py-3">
          <p className="text-xs text-vault-danger">{error}</p>
        </div>
      )}
    </div>
  )
}
