import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
} from 'viem'

const ERROR_MESSAGES: Record<string, string> = {
  // V1
  Vault__AlreadyDeposited: 'You already have an active deposit. Withdraw first.',
  Vault__NothingToWithdraw: 'No active deposit found.',
  // V2
  Vault__ZeroAmount: 'Deposit amount must be greater than zero.',
  Vault__LockDurationInvalid: 'Lock duration must be between 1 day and 365 days.',
  Vault__AssetNotWhitelisted: 'This token is not accepted by the vault.',
  Vault__ETHValueMismatch: 'Do not send ETH when depositing an ERC-20 token.',
  Vault__InvalidVaultId: 'Vault not found.',
  Vault__AlreadyWithdrawn: 'This vault has already been withdrawn.',
  Vault__NotYetUnlocked: 'Your funds are still locked.',
  Vault__TransferFailed: 'Transfer failed. Please try again.',
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
