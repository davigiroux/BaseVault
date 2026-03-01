import type { Address } from 'viem'
import { baseVaultAbi } from './abi'

export const VAULT_ABI = baseVaultAbi

export const VAULT_ADDRESS: Address = '0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408'

export type VaultDeposit = {
  amount: bigint
  unlocksAt: bigint
}
