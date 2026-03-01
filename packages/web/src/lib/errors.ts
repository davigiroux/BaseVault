import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
} from 'viem'

const ERROR_MESSAGES: Record<string, string> = {
  Vault__ZeroAmount: 'Deposit amount must be greater than zero.',
  Vault__LockDurationInvalid: 'Lock duration must be between 1 day and 365 days.',
  Vault__AlreadyDeposited: 'You already have an active deposit. Withdraw first.',
  Vault__NothingToWithdraw: 'No active deposit found.',
  Vault__NotYetUnlocked: 'Your funds are still locked.',
  Vault__TransferFailed: 'ETH transfer failed. Please try again.',
  ReentrancyGuardReentrantCall: 'Unexpected reentry error.',
}

export function parseVaultError(err: unknown): string {
  if (err instanceof BaseError) {
    const revert = err.walk(
      (e) => e instanceof ContractFunctionRevertedError
    )
    if (revert instanceof ContractFunctionRevertedError) {
      const name = revert.data?.errorName ?? ''
      return ERROR_MESSAGES[name] ?? 'Transaction reverted.'
    }
    if (err.walk((e) => e instanceof UserRejectedRequestError)) {
      return 'Transaction rejected.'
    }
  }
  return 'An unexpected error occurred.'
}
