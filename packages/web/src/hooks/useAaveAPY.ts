import { useReadContract } from 'wagmi'
import type { Address } from 'viem'
import { isETH } from '../lib/tokens'

// Base Sepolia Aave v3 Pool (from DeployV2.s.sol)
const AAVE_POOL: Address = '0x8bAB6d1b75f19e9eD9fCe8b9BD338844fF79aE27'
// ETH is supplied as WETH through the gateway; use WETH for reserve lookup
const WETH: Address = '0x4200000000000000000000000000000000000006'

const SECONDS_PER_YEAR = 31_536_000

// Minimal ABI — only the fields needed from getReserveData
const AAVE_POOL_ABI = [
  {
    name: 'getReserveData',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'asset', type: 'address' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'configuration', type: 'tuple', components: [{ name: 'data', type: 'uint256' }] },
          { name: 'liquidityIndex', type: 'uint128' },
          { name: 'currentLiquidityRate', type: 'uint128' },
          { name: 'variableBorrowIndex', type: 'uint128' },
          { name: 'currentVariableBorrowRate', type: 'uint128' },
          { name: 'currentStableBorrowRate', type: 'uint128' },
          { name: 'lastUpdateTimestamp', type: 'uint40' },
          { name: 'id', type: 'uint16' },
          { name: 'aTokenAddress', type: 'address' },
          { name: 'stableDebtTokenAddress', type: 'address' },
          { name: 'variableDebtTokenAddress', type: 'address' },
          { name: 'interestRateStrategyAddress', type: 'address' },
          { name: 'accruedToTreasury', type: 'uint128' },
          { name: 'unbacked', type: 'uint128' },
          { name: 'isolationModeTotalDebt', type: 'uint128' },
        ],
      },
    ],
  },
] as const

export function useAaveAPY(asset: Address) {
  // ETH vaults supply WETH to Aave — look up WETH reserve rate
  const reserveAsset = isETH(asset) ? WETH : asset

  const { data, isLoading } = useReadContract({
    address: AAVE_POOL,
    abi: AAVE_POOL_ABI,
    functionName: 'getReserveData',
    args: [reserveAsset],
    query: {
      staleTime: 60_000, // rate changes slowly — cache for 1 min
    },
  })

  if (!data || isLoading) return { apy: null, isLoading }

  // currentLiquidityRate is APR in Ray units (1e27), per second
  const aprPerSecond = Number(data.currentLiquidityRate) / 1e27
  // Compound: APY = (1 + APR/secondsPerYear)^secondsPerYear - 1
  const apy = (Math.pow(1 + aprPerSecond / SECONDS_PER_YEAR, SECONDS_PER_YEAR) - 1) * 100

  return { apy, isLoading: false }
}
