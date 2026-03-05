# Polymarket Clone

A native iOS client for [Polymarket](https://polymarket.com) — the world's largest prediction market. Browse markets, place bets, and manage positions directly from your iPhone with an embedded Polygon wallet.

## Features

- **Browse Markets** — Live events sorted by volume with category filtering and search
- **Trending Section** — Top markets displayed as visual cards
- **Price Charts** — Interactive historical price charts with multiple time ranges (1D, 1W, 1M, 6M)
- **Place Orders** — Buy Yes/No outcomes via Polymarket's CLOB (Central Limit Order Book)
- **Portfolio** — View real positions, P&L, and current value fetched from Polymarket's Data API
- **Wallet** — Embedded Polygon wallet with USDC balance, send/receive, and QR code
- **Authentication** — Email OTP and Apple Sign-In via Privy

## Architecture

Fully client-side — no backend needed. The app signs all transactions on-device using Privy's embedded wallet.

```
PolymarketClone/
├── PolymarketCloneApp.swift     # App entry point
├── ContentView.swift            # Tab container (Markets + Wallet)
├── AuthManager.swift            # Privy auth + embedded wallet management
│
├── Models
│   └── Market.swift             # Event, Market, Position, PricePoint models
│
├── View Model
│   └── MarketViewModel.swift    # Markets, positions, balance, order placement
│
├── Services
│   ├── NetworkService.swift     # Polymarket Gamma API + Data API
│   ├── ClobService.swift        # CLOB order signing (EIP-712) + HMAC auth
│   ├── TradingService.swift     # Trading orchestration
│   └── WalletService.swift      # On-chain RPC (balance, approvals, transfers)
│
├── Markets Tab
│   ├── MarketsTabView.swift     # Market list with search + categories
│   ├── EventRowView.swift       # Event list row
│   ├── TrendingCardView.swift   # Trending market card
│   ├── EventDetailSheet.swift   # Event detail with charts + outcomes
│   └── BetSheetView.swift       # Order placement sheet
│
├── Wallet Tab
│   ├── WalletTabView.swift      # Balance, send/receive, positions list
│   └── PositionDetailSheet.swift # Position detail with P&L + sell
│
└── Shared
    ├── LoginView.swift          # Email OTP + Apple Sign-In
    └── ErrorView.swift          # Error state with retry
```

## APIs Used

| API | Purpose | Auth |
|-----|---------|------|
| [Gamma API](https://gamma-api.polymarket.com) | Fetch events & markets | None |
| [CLOB API](https://clob.polymarket.com) | Place orders, market info | EIP-712 + HMAC |
| [Data API](https://data-api.polymarket.com) | User positions | None |
| Polygon RPC | Balances, approvals, transfers | None |

## Setup

### Prerequisites

- Xcode 15+
- iOS 17+
- A [Privy](https://privy.io) account with an app configured for embedded wallets

### Configuration

1. Clone the repo
2. Create `PolymarketClone/PolymarketClone/Secrets.xcconfig`:
   ```
   PRIVY_APP_ID = your_privy_app_id
   PRIVY_CLIENT_ID = your_privy_client_id
   ```
3. Open `PolymarketClone/PolymarketClone.xcodeproj` in Xcode
4. Build and run on a simulator or device

### Funding Your Wallet

To place orders you need USDC.e on Polygon:

1. Log in and go to the Wallet tab
2. Copy your wallet address or scan the QR code
3. Send USDC (Polygon) to that address from any exchange or wallet
4. You also need a small amount of POL for gas fees

## Key Technical Details

- **Order Signing**: EIP-712 typed data signed on-device via Privy SDK
- **CLOB Auth**: Two-layer auth — L1 (EIP-712 signature to derive API keys) + L2 (HMAC-SHA256 per request)
- **Approvals**: Three contracts need USDC + ERC-1155 approval — CTF Exchange, NegRisk Exchange, NegRisk Adapter
- **NegRisk Markets**: Multi-outcome markets only have a Yes token orderbook. "Buy No" = SELL the Yes token
- **Minimum Order**: Polymarket enforces a minimum of 5 shares per order

## License

This project is for educational purposes only. Polymarket is a registered trademark of Polymarket Inc.
