import { useVaults } from '../hooks/useVaults'
import { VAULT_V2_ADDRESS } from '../lib/contract'
import { VaultCard } from './VaultCard'

export function VaultList() {
  const { vaults, isLoading, error, refetch } = useVaults()

  if (!VAULT_V2_ADDRESS) {
    return (
      <div className="animate-fade-in">
        <div className="mb-4 flex items-center gap-2">
          <div className="h-px flex-1 bg-vault-border" />
          <span className="font-mono text-xs uppercase tracking-widest text-vault-muted">
            Your Vaults
          </span>
          <div className="h-px flex-1 bg-vault-border" />
        </div>
        <div className="rounded-lg border border-vault-border bg-vault-surface p-8 text-center">
          <p className="text-sm text-vault-muted">Contract not yet deployed</p>
          <p className="mt-1 text-xs text-vault-muted/60">
            Set VITE_VAULT_V2_ADDRESS_SEPOLIA in .env.local
          </p>
        </div>
      </div>
    )
  }

  return (
    <div className="animate-fade-in">
      <div className="mb-4 flex items-center gap-2">
        <div className="h-px flex-1 bg-vault-border" />
        <span className="font-mono text-xs uppercase tracking-widest text-vault-muted">
          Your Vaults
        </span>
        <div className="h-px flex-1 bg-vault-border" />
      </div>

      {isLoading && (
        <div className="flex items-center gap-3 rounded-lg border border-vault-border bg-vault-surface p-4">
          <div className="h-3 w-3 rounded-full bg-vault-muted animate-pulse-glow" />
          <span className="font-mono text-sm text-vault-muted">
            Loading vaults...
          </span>
        </div>
      )}

      {!isLoading && error && (
        <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-4 py-3">
          <p className="text-xs text-vault-danger">
            Failed to load vaults. Please refresh.
          </p>
        </div>
      )}

      {!isLoading && !error && vaults.length === 0 && (
        <div className="rounded-lg border border-vault-border bg-vault-surface p-8 text-center">
          <p className="text-sm text-vault-muted">No active vaults</p>
          <p className="mt-1 text-xs text-vault-muted/60">
            Create your first vault below
          </p>
        </div>
      )}

      {!isLoading && !error && vaults.length > 0 && (
        <div className="space-y-3">
          {vaults.map((vault) => (
            <VaultCard
              key={Number(vault.id)}
              vault={vault}
              onWithdrawSuccess={refetch}
            />
          ))}
        </div>
      )}
    </div>
  )
}
