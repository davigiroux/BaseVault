import type { ReactNode } from 'react'
import { ConnectButton } from './ConnectButton'

export function Layout({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-screen bg-vault-bg font-sans">
      {/* Subtle top-edge line */}
      <div className="h-px bg-gradient-to-r from-transparent via-vault-border to-transparent" />

      <header className="border-b border-vault-border">
        <div className="mx-auto flex max-w-2xl items-center justify-between px-4 py-4 sm:px-6">
          <div className="flex items-center gap-2.5">
            {/* Vault icon — geometric lock shape */}
            <svg
              width="20"
              height="20"
              viewBox="0 0 20 20"
              fill="none"
              className="text-vault-accent"
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
            <span className="text-lg font-semibold tracking-tight text-vault-text">
              BaseVault
            </span>
          </div>
          <ConnectButton />
        </div>
      </header>

      <main className="mx-auto max-w-2xl px-4 py-8 sm:px-6 sm:py-12">
        {children}
      </main>

      <footer className="border-t border-vault-border">
        <div className="mx-auto max-w-2xl px-4 py-4 sm:px-6">
          <p className="text-center font-mono text-xs text-vault-muted">
            Commitment savings on Base
          </p>
        </div>
      </footer>
    </div>
  )
}
