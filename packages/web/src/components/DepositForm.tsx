import { type FormEvent, useState } from 'react'
import { useDeposit } from '../hooks/useDeposit'
import { useVault } from '../hooks/useVault'

const MIN_DAYS = 1
const MAX_DAYS = 365
const SECONDS_PER_DAY = 86400

export function DepositForm() {
  const { deposit, isPending, isConfirming, isSuccess, error, reset } =
    useDeposit()
  const { hasDeposit, refetch } = useVault()

  const [amount, setAmount] = useState('')
  const [days, setDays] = useState(30)
  const [validationError, setValidationError] = useState<string | null>(null)

  const isProcessing = isPending || isConfirming

  function validate(): boolean {
    const parsed = parseFloat(amount)
    if (!amount || isNaN(parsed) || parsed <= 0) {
      setValidationError('Enter an amount greater than 0.')
      return false
    }
    if (days < MIN_DAYS || days > MAX_DAYS) {
      setValidationError(`Lock duration must be ${MIN_DAYS}–${MAX_DAYS} days.`)
      return false
    }
    setValidationError(null)
    return true
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault()
    if (!validate()) return
    await deposit(amount, BigInt(days * SECONDS_PER_DAY))
    refetch()
  }

  function handleReset() {
    setAmount('')
    setDays(30)
    setValidationError(null)
    reset()
  }

  if (isSuccess) {
    return (
      <div className="animate-fade-in rounded-lg border border-vault-success/20 bg-vault-success/5 p-6 text-center">
        <div className="mx-auto mb-3 flex h-10 w-10 items-center justify-center rounded-full bg-vault-success/10">
          <svg
            width="20"
            height="20"
            viewBox="0 0 16 16"
            fill="none"
            className="text-vault-success"
          >
            <path
              d="M3 8l3.5 3.5L13 5"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
        <p className="text-sm font-medium text-vault-success">
          Deposit confirmed
        </p>
        <p className="mt-1 text-xs text-vault-muted">
          Your ETH is now locked in the vault.
        </p>
        <button
          onClick={handleReset}
          className="mt-4 font-mono text-xs text-vault-muted underline decoration-vault-border underline-offset-4 transition-colors hover:text-vault-text"
        >
          Done
        </button>
      </div>
    )
  }

  const displayError = validationError ?? error

  return (
    <form onSubmit={handleSubmit} className="animate-fade-in space-y-5">
      <div>
        <div className="mb-4 flex items-center gap-2">
          <div className="h-px flex-1 bg-vault-border" />
          <span className="font-mono text-xs uppercase tracking-widest text-vault-muted">
            New Deposit
          </span>
          <div className="h-px flex-1 bg-vault-border" />
        </div>
      </div>

      {hasDeposit && (
        <div className="rounded-md border border-vault-accent/20 bg-vault-accent/5 px-4 py-3">
          <p className="text-xs text-vault-accent">
            You already have an active deposit. Withdraw first to make a new
            one.
          </p>
        </div>
      )}

      {/* Amount input */}
      <div>
        <label
          htmlFor="amount"
          className="mb-2 block text-xs uppercase tracking-widest text-vault-muted"
        >
          Amount
        </label>
        <div className="relative">
          <input
            id="amount"
            type="text"
            inputMode="decimal"
            placeholder="0.00"
            value={amount}
            onChange={(e) => {
              setAmount(e.target.value)
              setValidationError(null)
            }}
            disabled={hasDeposit || isProcessing}
            className="w-full rounded-lg border border-vault-border bg-vault-bg px-4 py-3 pr-14 font-mono text-lg text-vault-text placeholder:text-vault-muted/40 transition-colors focus:border-vault-border-hover focus:outline-none disabled:cursor-not-allowed disabled:opacity-40"
          />
          <span className="absolute right-4 top-1/2 -translate-y-1/2 font-mono text-sm text-vault-muted">
            ETH
          </span>
        </div>
      </div>

      {/* Lock duration */}
      <div>
        <label
          htmlFor="duration"
          className="mb-2 block text-xs uppercase tracking-widest text-vault-muted"
        >
          Lock duration
        </label>
        <div className="space-y-3">
          <div className="flex items-center gap-3">
            <input
              id="duration"
              type="range"
              min={MIN_DAYS}
              max={MAX_DAYS}
              value={days}
              onChange={(e) => setDays(Number(e.target.value))}
              disabled={hasDeposit || isProcessing}
              className="h-1 flex-1 cursor-pointer appearance-none rounded-full bg-vault-border accent-vault-text disabled:cursor-not-allowed disabled:opacity-40"
            />
            <div className="flex items-baseline gap-1">
              <input
                type="number"
                min={MIN_DAYS}
                max={MAX_DAYS}
                value={days}
                onChange={(e) => {
                  const v = Number(e.target.value)
                  if (v >= MIN_DAYS && v <= MAX_DAYS) setDays(v)
                }}
                disabled={hasDeposit || isProcessing}
                className="w-16 rounded-md border border-vault-border bg-vault-bg px-2 py-1.5 text-right font-mono text-sm text-vault-text focus:border-vault-border-hover focus:outline-none disabled:cursor-not-allowed disabled:opacity-40"
              />
              <span className="font-mono text-xs text-vault-muted">days</span>
            </div>
          </div>
          <div className="flex justify-between font-mono text-[10px] text-vault-muted/50">
            <span>1 day</span>
            <span>1 year</span>
          </div>
        </div>
      </div>

      {/* Error */}
      {displayError && (
        <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-4 py-3">
          <p className="text-xs text-vault-danger">{displayError}</p>
        </div>
      )}

      {/* Submit */}
      <button
        type="submit"
        disabled={hasDeposit || isProcessing}
        className="w-full rounded-lg border border-vault-border bg-vault-surface px-4 py-3 font-mono text-sm font-medium text-vault-text transition-all hover:border-vault-border-hover hover:bg-vault-border/30 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-40 disabled:active:scale-100"
      >
        {isPending
          ? 'Confirm in wallet...'
          : isConfirming
            ? 'Confirming...'
            : 'Lock ETH'}
      </button>
    </form>
  )
}
