import { useVault } from '../hooks/useVault'
import {
  formatEthAmount,
  formatCountdown,
  formatUnlockDate,
} from '../lib/format'

export function VaultStatus() {
  const { deposit, hasDeposit, isLocked, secondsRemaining, isLoading } =
    useVault()

  if (isLoading) {
    return (
      <div className="animate-fade-in rounded-lg border border-vault-border bg-vault-surface p-6">
        <div className="flex items-center gap-3">
          <div className="h-3 w-3 rounded-full bg-vault-muted animate-pulse-glow" />
          <span className="font-mono text-sm text-vault-muted">
            Loading vault...
          </span>
        </div>
      </div>
    )
  }

  if (!hasDeposit) {
    return (
      <div className="animate-fade-in rounded-lg border border-dashed border-vault-border bg-vault-surface/50 p-8 text-center">
        <div className="mx-auto mb-3 flex h-10 w-10 items-center justify-center rounded-full border border-vault-border">
          <svg
            width="18"
            height="18"
            viewBox="0 0 20 20"
            fill="none"
            className="text-vault-muted"
          >
            <rect
              x="2"
              y="9"
              width="16"
              height="10"
              rx="2"
              stroke="currentColor"
              strokeWidth="1.5"
            />
            <path
              d="M6 9V6a4 4 0 1 1 8 0v3"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
          </svg>
        </div>
        <p className="text-sm font-medium text-vault-muted">
          No active deposit
        </p>
        <p className="mt-1 text-xs text-vault-muted/60">
          Lock ETH to start your commitment
        </p>
      </div>
    )
  }

  return (
    <div className="animate-fade-in space-y-4">
      {/* Status indicator bar */}
      <div className="flex items-center gap-2">
        <div
          className={`h-2 w-2 rounded-full ${
            isLocked ? 'bg-vault-accent animate-pulse-glow' : 'bg-vault-success'
          }`}
        />
        <span className="font-mono text-xs uppercase tracking-widest text-vault-muted">
          {isLocked ? 'Locked' : 'Unlocked'}
        </span>
      </div>

      <div className="rounded-lg border border-vault-border bg-vault-surface p-6">
        {/* Amount */}
        <div className="mb-6">
          <p className="mb-1 text-xs uppercase tracking-widest text-vault-muted">
            Deposited
          </p>
          <p className="font-mono text-3xl font-bold tracking-tight text-vault-text sm:text-4xl">
            {formatEthAmount(deposit!.amount)}
          </p>
        </div>

        {/* Divider */}
        <div className="mb-6 h-px bg-vault-border" />

        {/* Countdown or unlocked state */}
        {isLocked ? (
          <div className="space-y-3">
            <div>
              <p className="mb-1 text-xs uppercase tracking-widest text-vault-muted">
                Time remaining
              </p>
              <p className="font-mono text-xl font-semibold tracking-wide text-vault-accent">
                {formatCountdown(secondsRemaining)}
              </p>
            </div>
            <div>
              <p className="mb-1 text-xs uppercase tracking-widest text-vault-muted">
                Unlocks on
              </p>
              <p className="font-mono text-sm text-vault-muted">
                {formatUnlockDate(deposit!.unlocksAt)}
              </p>
            </div>
          </div>
        ) : (
          <div className="flex items-center gap-3">
            <div className="flex h-8 w-8 items-center justify-center rounded-full bg-vault-success/10">
              <svg
                width="16"
                height="16"
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
            <div>
              <p className="text-sm font-medium text-vault-success">
                Ready to withdraw
              </p>
              <p className="text-xs text-vault-muted">
                Your lock period has ended
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
