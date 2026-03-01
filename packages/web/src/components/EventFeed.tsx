import { useChainId, useBalance } from 'wagmi'
import { useVaultEvents } from '../hooks/useVaultEvents'
import {
  formatEthAmount,
  truncateAddress,
  formatRelativeTime,
} from '../lib/format'
import { getAddressUrl, getTxUrl } from '../lib/chain'
import { VAULT_ADDRESS } from '../lib/contract'
import type { VaultEvent } from '../lib/events'

function EventRow({
  event,
  chainId,
}: {
  event: VaultEvent
  chainId: number
}) {
  const isDeposit = event.type === 'deposit'

  return (
    <div className="flex items-center justify-between gap-3 py-3">
      <div className="flex items-center gap-3">
        {/* Type indicator */}
        <div
          className={`flex h-7 w-7 shrink-0 items-center justify-center rounded-full ${
            isDeposit
              ? 'bg-vault-accent/10 text-vault-accent'
              : 'bg-vault-success/10 text-vault-success'
          }`}
        >
          {isDeposit ? (
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
              <path
                d="M8 3v10M4 9l4 4 4-4"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          ) : (
            <svg width="14" height="14" viewBox="0 0 16 16" fill="none">
              <path
                d="M8 13V3M4 7l4-4 4 4"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
          )}
        </div>

        <div className="min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-xs font-medium text-vault-text">
              {isDeposit ? 'Deposit' : 'Withdrawal'}
            </span>
            <a
              href={getAddressUrl(chainId, event.depositor)}
              target="_blank"
              rel="noopener noreferrer"
              className="font-mono text-xs text-vault-muted transition-colors hover:text-vault-accent"
            >
              {truncateAddress(event.depositor)}
            </a>
          </div>
          {event.timestamp !== null && (
            <p className="text-[10px] text-vault-muted/60">
              {formatRelativeTime(event.timestamp)}
            </p>
          )}
        </div>
      </div>

      <a
        href={getTxUrl(chainId, event.transactionHash)}
        target="_blank"
        rel="noopener noreferrer"
        className="shrink-0 font-mono text-sm font-medium text-vault-text transition-colors hover:text-vault-accent"
      >
        {formatEthAmount(event.amount)}
      </a>
    </div>
  )
}

export function EventFeed() {
  const { events, isLoading, error } = useVaultEvents()
  const chainId = useChainId()
  const { data: balance } = useBalance({ address: VAULT_ADDRESS })

  return (
    <div className="animate-fade-in">
      {/* Section header */}
      <div className="mb-4 flex items-center gap-2">
        <div className="h-px flex-1 bg-vault-border" />
        <span className="font-mono text-xs uppercase tracking-widest text-vault-muted">
          Activity
        </span>
        <div className="h-px flex-1 bg-vault-border" />
      </div>

      {/* TVL stat */}
      {balance && balance.value > 0n && (
        <div className="mb-3 flex items-center justify-between rounded-md border border-vault-border bg-vault-surface/50 px-4 py-2">
          <span className="text-xs uppercase tracking-widest text-vault-muted">
            Total Locked
          </span>
          <span className="font-mono text-sm font-semibold text-vault-text">
            {formatEthAmount(balance.value)}
          </span>
        </div>
      )}

      <div className="rounded-lg border border-vault-border bg-vault-surface p-4">
        {/* Loading */}
        {isLoading && (
          <div className="flex items-center gap-3 py-4">
            <div className="h-3 w-3 rounded-full bg-vault-muted animate-pulse-glow" />
            <span className="font-mono text-sm text-vault-muted">
              Loading activity...
            </span>
          </div>
        )}

        {/* Error */}
        {!isLoading && error && (
          <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-4 py-3">
            <p className="text-xs text-vault-danger">{error}</p>
          </div>
        )}

        {/* Empty */}
        {!isLoading && !error && events.length === 0 && (
          <p className="py-4 text-center text-sm text-vault-muted">
            No vault activity yet
          </p>
        )}

        {/* Event list */}
        {!isLoading && !error && events.length > 0 && (
          <div className="divide-y divide-vault-border">
            {events.map((event) => (
              <EventRow key={event.id} event={event} chainId={chainId} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
