import { existsSync, readFileSync, writeFileSync } from 'fs'

const src = '../contracts/out/BaseVaultV2.sol/BaseVaultV2.json'

if (!existsSync(src)) {
  console.log('Foundry output not found — using committed abi.ts')
  process.exit(0)
}

const artifact = JSON.parse(readFileSync(src, 'utf8'))

const output = `// Auto-generated from Foundry build output. Do not edit.
export const baseVaultV2Abi = ${JSON.stringify(artifact.abi, null, 2)} as const
`

writeFileSync('src/lib/abi.ts', output)
console.log('V2 ABI copied from Foundry output')
