import { readFileSync, writeFileSync } from 'fs'

const artifact = JSON.parse(
  readFileSync('../contracts/out/BaseVault.sol/BaseVault.json', 'utf8')
)

const output = `// Auto-generated from Foundry build output. Do not edit.
export const baseVaultAbi = ${JSON.stringify(artifact.abi, null, 2)} as const
`

writeFileSync('src/lib/abi.ts', output)
console.log('ABI copied from Foundry output')
