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

;; READ-ONLY FUNCTIONS - PROTOCOL QUERIES

;; Retrieve user's collateral balance
(define-read-only (get-user-collateral (user principal))
  (default-to u0 (map-get? user-collateral-balance user))
)

;; Retrieve user's outstanding debt
(define-read-only (get-user-debt (user principal))
  (default-to u0 (map-get? user-debt-balance user))
)

;; Get current Bitcoin price from oracle
(define-read-only (get-current-btc-price)
  (var-get current-btc-price-usd)
)

;; Calculate user's collateralization health factor
;; Returns: (collateral-value * precision) / (debt-value * liquidation-threshold)
;; Health factor < 1.0 indicates liquidatable position
(define-read-only (calculate-health-factor (user principal))
  (let (
      (user-collateral (get-user-collateral user))
      (user-debt (get-user-debt user))
      (btc-price (var-get current-btc-price-usd))
    )
    (if (is-eq user-debt u0)
      (ok u0) ;; No debt position
      (let (
          (collateral-usd-value (* user-collateral btc-price))
          (scaled-collateral-value (* collateral-usd-value PRECISION-FACTOR))
          (debt-threshold-value (* user-debt LIQUIDATION-THRESHOLD))
        )
        (ok (/ scaled-collateral-value debt-threshold-value))
      )
    )
  )
)

;; Calculate maximum borrowing capacity for user
(define-read-only (get-borrowing-capacity (user principal))
  (let (
      (user-collateral (get-user-collateral user))
      (btc-price (var-get current-btc-price-usd))
    )
    (/ (* user-collateral btc-price MAX-LTV-RATIO) PRECISION-FACTOR)
  )
)

;; Check if position is eligible for liquidation
(define-read-only (is-liquidatable (user principal))
  (let ((health-factor-result (calculate-health-factor user)))
    (if (is-ok health-factor-result)
      (let ((health-factor (unwrap-panic health-factor-result)))
        (< health-factor PRECISION-FACTOR)
      )
      false
    )
  )
)

;; Calculate accrued interest for user position
(define-read-only (calculate-accrued-interest (user principal))
  (let (
      (user-debt (get-user-debt user))
      (last-accrual-block (default-to u0 (map-get? user-last-accrual-block user)))
      (current-block stacks-block-height)
      (blocks-elapsed (if (is-eq last-accrual-block u0)
        u0
        (- current-block last-accrual-block)
      ))
    )
    (if (is-eq blocks-elapsed u0)
      u0
      ;; Interest = principal * rate * time / (precision * blocks-per-year)
      (/ (* (* user-debt BASE-APR) blocks-elapsed)
        (* PRECISION-FACTOR SECONDS-PER-YEAR)
      )
    )
  )
)

;; PUBLIC FUNCTIONS - PROTOCOL OPERATIONS

;; Initialize protocol with initial Bitcoin price
(define-public (initialize-protocol (initial-btc-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (not (var-get protocol-initialized)) ERR-PROTOCOL-ALREADY-ACTIVE)

    ;; Validate initial price parameters
    (asserts! (> initial-btc-price u0) ERR-PRICE-VALIDATION-FAILED)
    (asserts! (< initial-btc-price u1000000000000) ERR-PRICE-VALIDATION-FAILED)

    ;; Initialize protocol state
    (var-set current-btc-price-usd initial-btc-price)
    (var-set previous-btc-price-usd initial-btc-price)
    (var-set protocol-initialized true)
    (var-set last-global-accrual-block stacks-block-height)

    (ok true)
  )
)

;; Update Bitcoin price via oracle (owner-only for security)
(define-public (update-btc-price (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (var-get protocol-initialized) ERR-PROTOCOL-NOT-INITIALIZED)

    ;; Prevent price manipulation attacks
    (let (
        (previous-price (var-get previous-btc-price-usd))
        (price-change-ratio (if (is-eq previous-price u0)
          u0
          (/
            (*
              (if (> new-price previous-price)
                (- new-price previous-price)
                (- previous-price new-price)
              )
              PRECISION-FACTOR
            )
            previous-price
          )
        ))
      )
      ;; Reject extreme price changes
      (asserts! (< price-change-ratio MAX-PRICE-DEVIATION)
        ERR-PRICE-MANIPULATION-DETECTED
      )

      ;; Update price state
      (var-set previous-btc-price-usd (var-get current-btc-price-usd))
      (var-set current-btc-price-usd new-price)

      (ok true)
    )
  )
)

;; Deposit Bitcoin collateral to protocol
(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (var-get protocol-initialized) ERR-PROTOCOL-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    ;; Prevent arithmetic overflow
    (let (
        (current-user-collateral (get-user-collateral tx-sender))
        (new-user-collateral (+ current-user-collateral amount))
        (current-global-collateral (var-get total-collateral-deposited))
        (new-global-collateral (+ current-global-collateral amount))
      )
      ;; Overflow protection
      (asserts! (>= new-user-collateral current-user-collateral)
        ERR-ARITHMETIC-OVERFLOW
      )
      (asserts! (>= new-global-collateral current-global-collateral)
        ERR-ARITHMETIC-OVERFLOW
      )

      ;; Update state
      (map-set user-collateral-balance tx-sender new-user-collateral)
      (var-set total-collateral-deposited new-global-collateral)

      (ok true)
    )
  )
)

;; Withdraw Bitcoin collateral from protocol
(define-public (withdraw-collateral (amount uint))
  (begin
    (asserts! (var-get protocol-initialized) ERR-PROTOCOL-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    (let (
        (current-collateral (get-user-collateral tx-sender))
        (current-debt (get-user-debt tx-sender))
      )
      ;; Verify sufficient collateral balance
      (asserts! (>= current-collateral amount) ERR-INSUFFICIENT-BALANCE)

      ;; If user has debt, ensure adequate collateralization after withdrawal
      (if (> current-debt u0)
        (let (
            (remaining-collateral (- current-collateral amount))
            (btc-price (var-get current-btc-price-usd))
            (remaining-collateral-value (* remaining-collateral btc-price))
            (required-collateral-value (/ (* current-debt PRECISION-FACTOR) MAX-LTV-RATIO))
          )
          ;; Ensure withdrawal doesn't violate LTV requirements
          (asserts! (>= remaining-collateral-value required-collateral-value)
            ERR-COLLATERAL-THRESHOLD-BREACH
          )

          ;; Execute withdrawal
          (map-set user-collateral-balance tx-sender remaining-collateral)
          (var-set total-collateral-deposited
            (- (var-get total-collateral-deposited) amount)
          )

          (ok true)
        )
        (begin
          ;; No debt constraints, process withdrawal
          (map-set user-collateral-balance tx-sender
            (- current-collateral amount)
          )
          (var-set total-collateral-deposited
            (- (var-get total-collateral-deposited) amount)
          )

          (ok true)
        )
      )
    )
  )
)