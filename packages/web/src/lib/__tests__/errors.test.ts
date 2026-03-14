import { describe, it, expect } from 'vitest'
import {
  BaseError,
  ContractFunctionRevertedError,
  UserRejectedRequestError,
} from 'viem'
import { parseVaultError } from '../errors'

function makeRevertError(errorName: string): BaseError {
  const revert = Object.create(ContractFunctionRevertedError.prototype)
  revert.data = { errorName }
  revert.name = 'ContractFunctionRevertedError'

  const base = new BaseError('revert', { cause: revert })
  return base
}

function makeUserRejectedError(): BaseError {
  const rejected = Object.create(UserRejectedRequestError.prototype)
  rejected.name = 'UserRejectedRequestError'

  return new BaseError('rejected', { cause: rejected })
}

describe('parseVaultError', () => {
  it('maps Vault__ZeroAmount', () => {
    expect(parseVaultError(makeRevertError('Vault__ZeroAmount'))).toBe(
      'Deposit amount must be greater than zero.',
    )
  })

  it('maps Vault__LockDurationInvalid', () => {
    expect(
      parseVaultError(makeRevertError('Vault__LockDurationInvalid')),
    ).toBe('Lock duration must be between 1 day and 365 days.')
  })

  it('maps Vault__AlreadyDeposited', () => {
    expect(parseVaultError(makeRevertError('Vault__AlreadyDeposited'))).toBe(
      'You already have an active deposit. Withdraw first.',
    )
  })

  it('maps Vault__NothingToWithdraw', () => {
    expect(parseVaultError(makeRevertError('Vault__NothingToWithdraw'))).toBe(
      'No active deposit found.',
    )
  })

  it('maps Vault__NotYetUnlocked', () => {
    expect(parseVaultError(makeRevertError('Vault__NotYetUnlocked'))).toBe(
      'Your funds are still locked.',
    )
  })

  it('maps Vault__TransferFailed', () => {
    expect(parseVaultError(makeRevertError('Vault__TransferFailed'))).toBe(
      'Transfer failed. Please try again.',
    )
  })

  it('maps unknown revert to generic message', () => {
    expect(parseVaultError(makeRevertError('SomeUnknownError'))).toBe(
      'Transaction reverted.',
    )
  })

  it('maps UserRejectedRequestError', () => {
    expect(parseVaultError(makeUserRejectedError())).toBe(
      'Transaction rejected.',
    )
  })

  it('returns fallback for non-BaseError', () => {
    expect(parseVaultError(new Error('random'))).toBe(
      'An unexpected error occurred.',
    )
  })

  it('returns fallback for string error', () => {
    expect(parseVaultError('something broke')).toBe(
      'An unexpected error occurred.',
    )
  })
})
