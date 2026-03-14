import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RainbowKitProvider, darkTheme } from '@rainbow-me/rainbowkit'
import '@rainbow-me/rainbowkit/styles.css'
import { useAccount } from 'wagmi'

import { wagmiConfig } from './lib/wagmi'
import { Layout } from './components/Layout'
import { VaultList } from './components/VaultList'
import { DepositForm } from './components/DepositForm'
import { EventFeed } from './components/EventFeed'

const queryClient = new QueryClient()

function VaultApp() {
  const { isConnected } = useAccount()

  return (
    <Layout>
      {isConnected ? (
        <div className="space-y-6">
          <VaultList />
          <DepositForm />
          <EventFeed />
        </div>
      ) : (
        <div className="animate-fade-in py-16 text-center">
          <div className="mx-auto mb-4 flex h-14 w-14 items-center justify-center rounded-full border border-vault-border">
            <svg
              width="24"
              height="24"
              viewBox="0 0 20 20"
              fill="none"
              className="text-vault-muted"
            >
              <rect
                x="2"
                y="9"
                width="16"
                height="10"
                rx="2"
                stroke="currentColor"
                strokeWidth="1.5"
              />
              <path
                d="M6 9V6a4 4 0 1 1 8 0v3"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
              />
              <circle cx="10" cy="14" r="1.5" fill="currentColor" />
            </svg>
          </div>
          <h2 className="mb-2 text-lg font-semibold text-vault-text">
            Connect your wallet
          </h2>
          <p className="mx-auto max-w-xs text-sm text-vault-muted">
            Connect a wallet on Base Sepolia to deposit ETH or tokens into
            time-locked vaults.
          </p>
        </div>
      )}
    </Layout>
  )
}

export default function App() {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider
          theme={darkTheme({
            accentColor: '#f59e0b',
            accentColorForeground: '#09090b',
            borderRadius: 'medium',
            fontStack: 'system',
          })}
        >
          <VaultApp />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
