import type { Address } from 'viem'
import { useTokenApproval } from '../hooks/useTokenApproval'
import { getTokenMeta } from '../lib/tokens'

type ApproveButtonProps = {
  token: Address
  amount: bigint
}

export function ApproveButton({ token, amount }: ApproveButtonProps) {
  const { approve, isPending, error } = useTokenApproval(token, amount)
  const symbol = getTokenMeta(token).symbol

  return (
    <div className="space-y-2">
      <button
        type="button"
        onClick={approve}
        disabled={isPending}
        className="w-full rounded-lg border border-vault-accent/30 bg-vault-accent/5 px-4 py-3 font-mono text-sm font-medium text-vault-accent transition-all hover:border-vault-accent/50 hover:bg-vault-accent/10 active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-40 disabled:active:scale-100"
      >
        {isPending
          ? 'Confirm in wallet...'
          : `Step 1 of 2: Approve ${symbol}`}
      </button>
      {error && (
        <div className="rounded-md border border-vault-danger/20 bg-vault-danger/5 px-4 py-3">
          <p className="text-xs text-vault-danger">{error}</p>
        </div>
      )}
    </div>
  )
}
