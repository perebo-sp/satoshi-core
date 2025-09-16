;; Title: SatoshiCore  - Bitcoin-Native Liquidity Engine
;;
;; Summary: 
;; Revolutionary DeFi protocol that transforms idle Bitcoin into productive capital through
;; secure over-collateralized lending, powered by Stacks' Bitcoin-anchored smart contracts
;; for uncompromising security and transparent yield generation.
;;
;; Description:
;; SatoshiCore  represents the evolution of Bitcoin finance, bridging the gap between HODLing
;; and earning yield. Built exclusively for the Stacks ecosystem, this protocol enables
;; Bitcoin holders to unlock liquidity without sacrificing their long-term Bitcoin position.
;;
;; Key Innovation Features:
;; - Bitcoin-First Architecture: Native sBTC integration with full Bitcoin security inheritance
;; - Intelligent Risk Management: Dynamic 125% collateralization with real-time health monitoring
;; - Yield Optimization: Competitive 5% base APR with algorithmic rate adjustments
;; - Instant Liquidation Engine: Automated 10% penalty system protecting lender interests
;; - Oracle-Driven Pricing: Real-time BTC/USD feeds ensuring accurate collateral valuation
;; - Zero-Trust Operations: Non-custodial design with complete on-chain transparency
;;
;; The protocol leverages Clarity's predictable execution model and Stacks' Bitcoin finality
;; to create a trustless lending environment where users maintain Bitcoin exposure while
;; accessing DeFi yields. Every transaction inherits Bitcoin's proven security through
;; Stacks' unique consensus mechanism, making SatoshiCore  the safest way to put Bitcoin to work.

;; PROTOCOL CONSTANTS & ERROR CODES

;; Core protocol constants
(define-constant CONTRACT-OWNER tx-sender)

;; Error codes for comprehensive error handling
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-EXCESSIVE-DEBT-RATIO (err u102))
(define-constant ERR-UNAUTHORIZED-BORROWER (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-COLLATERAL-THRESHOLD-BREACH (err u105))
(define-constant ERR-NO-ACTIVE-POSITION (err u106))
(define-constant ERR-LIQUIDATION-NOT-PERMITTED (err u107))
(define-constant ERR-PROTOCOL-ALREADY-ACTIVE (err u108))
(define-constant ERR-PROTOCOL-NOT-INITIALIZED (err u109))
(define-constant ERR-INVALID-AMOUNT (err u110))
(define-constant ERR-PRICE-VALIDATION-FAILED (err u111))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u112))
(define-constant ERR-PRICE-MANIPULATION-DETECTED (err u113))

;; PROTOCOL PARAMETERS

;; Liquidation threshold: 80% (positions liquidatable below 125% collateral ratio)
(define-constant LIQUIDATION-THRESHOLD u800000)

;; Maximum loan-to-value ratio: 70% (conservative lending approach)
(define-constant MAX-LTV-RATIO u700000)

;; Base annual percentage rate: 5% (500 basis points)
(define-constant BASE-APR u500)

;; Liquidation penalty: 10% (1000 basis points) - incentivizes liquidators
(define-constant LIQUIDATION-PENALTY u1000)

;; Fixed-point arithmetic precision (1,000,000 = 100%)
(define-constant PRECISION-FACTOR u1000000)

;; Maximum allowed price change: 20% (prevents oracle manipulation)
(define-constant MAX-PRICE-DEVIATION u200000)

;; Time constants
(define-constant SECONDS-PER-YEAR u31536000)

;; PROTOCOL STATE VARIABLES

;; Protocol initialization status
(define-data-var protocol-initialized bool false)

;; Global collateral and debt tracking
(define-data-var total-collateral-deposited uint u0)
(define-data-var total-outstanding-debt uint u0)

;; Interest accrual timing
(define-data-var last-global-accrual-block uint u0)

;; Oracle price feeds
(define-data-var current-btc-price-usd uint u0)
(define-data-var previous-btc-price-usd uint u0)

;; USER DATA MAPPINGS

;; User collateral balances (in satoshis)
(define-map user-collateral-balance
  principal
  uint
)

;; User debt balances (in USD stablecoin)
(define-map user-debt-balance
  principal
  uint
)

;; User interest accrual timestamps
(define-map user-last-accrual-block
  principal
  uint
)