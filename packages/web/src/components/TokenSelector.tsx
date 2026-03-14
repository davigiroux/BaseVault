import type { Address } from 'viem'
import { useWhitelistedAssets } from '../hooks/useWhitelistedAssets'

type TokenSelectorProps = {
  selectedToken: Address
  onTokenChange: (token: Address) => void
  disabled?: boolean
}

export function TokenSelector({
  selectedToken,
  onTokenChange,
  disabled = false,
}: TokenSelectorProps) {
  const { tokens, isLoading } = useWhitelistedAssets()

  return (
    <div>
      <label
        htmlFor="token"
        className="mb-2 block text-xs uppercase tracking-widest text-vault-muted"
      >
        Asset
      </label>
      <select
        id="token"
        value={selectedToken}
        onChange={(e) => onTokenChange(e.target.value as Address)}
        disabled={disabled || isLoading}
        className="w-full rounded-lg border border-vault-border bg-vault-bg px-4 py-3 font-mono text-sm text-vault-text transition-colors focus:border-vault-border-hover focus:outline-none disabled:cursor-not-allowed disabled:opacity-40"
      >
        {tokens.map((token) => (
          <option key={token.address} value={token.address}>
            {token.symbol} — {token.name}
          </option>
        ))}
      </select>
    </div>
  )
}
