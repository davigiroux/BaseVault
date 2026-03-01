.PHONY: install build test dev clean

# ── Setup ──────────────────────────────────────
install:
	pnpm install

# ── Contracts ──────────────────────────────────
build-contracts:
	cd packages/contracts && forge build

test-contracts:
	cd packages/contracts && forge test -vvv

coverage:
	cd packages/contracts && forge coverage

fmt-contracts:
	cd packages/contracts && forge fmt

deploy-sepolia:
	cd packages/contracts && forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --verify

# ── Frontend ───────────────────────────────────
dev:
	cd packages/web && pnpm dev

build-web:
	cd packages/web && pnpm build

typecheck:
	cd packages/web && pnpm typecheck

lint:
	cd packages/web && pnpm lint

# ── All ────────────────────────────────────────
build: build-contracts build-web

test: test-contracts typecheck

clean:
	cd packages/contracts && rm -rf out cache
	cd packages/web && rm -rf dist node_modules/.tmp
