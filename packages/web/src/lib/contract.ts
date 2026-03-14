import type { Address } from 'viem'
import { baseVaultV2Abi } from './abi'

export const VAULT_V2_ABI = baseVaultV2Abi
export const VAULT_V2_ADDRESS: Address | undefined =
  (import.meta.env.VITE_VAULT_V2_ADDRESS_SEPOLIA as Address) || undefined

export type Vault = {
  id: bigint
  asset: Address
  principal: bigint
  unlocksAt: bigint
  yielding: boolean
  aToken: Address
}

// V1 exports — kept for backward compat (tests)
export { baseVaultAbi as VAULT_V1_ABI } from './abi-v1'
export const VAULT_V1_ADDRESS: Address =
  '0xA428339ecF9CEC74f02adAe28d1cB24c935Dd408'
