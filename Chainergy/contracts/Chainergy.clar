;; Chainergy - Blockchain-Based Electricity Trading Smart Contract

;; === Constants ===
(define-constant chainergy-admin-principal tx-sender)
(define-constant chainergy-err-unauthorized-access (err u100))
(define-constant chainergy-err-insufficient-funds-balance (err u101))
(define-constant chainergy-err-transfer-failed-operation (err u102))
(define-constant chainergy-err-bad-price-value (err u103))
(define-constant chainergy-err-bad-amount-value (err u104))
(define-constant chainergy-err-bad-rate-value (err u105))
(define-constant chainergy-err-refund-failed-operation (err u106))
(define-constant chainergy-err-self-trade-attempt (err u107))
(define-constant chainergy-err-reserve-exceeded-limit (err u108))
(define-constant chainergy-err-bad-reserve-value (err u109))

;; === Global State ===
(define-data-var chainergy-unit-price-amount uint u100)                   ;; price per energy unit
(define-data-var chainergy-max-user-holdings-limit uint u10000)
(define-data-var chainergy-fee-rate-percentage uint u5)                       ;; % commission
(define-data-var chainergy-refund-rate-percentage uint u90)
(define-data-var chainergy-reserve-cap-limit uint u1000000)
(define-data-var chainergy-total-reserve-amount uint u0)

;; === User Data Maps ===
(define-map chainergy-energy-holdings-map principal uint)
(define-map chainergy-stx-holdings-map principal uint)
(define-map chainergy-listings-market-map {seller: principal} {units: uint, ask: uint})

;; === Private Helpers ===
(define-private (chainergy-calc-fee-amount (amount-input uint))
  (/ (* amount-input (var-get chainergy-fee-rate-percentage)) u100))

(define-private (chainergy-calc-refund-amount (units-input uint))
  (/ (* units-input (var-get chainergy-unit-price-amount) (var-get chainergy-refund-rate-percentage)) u100))

(define-private (chainergy-adjust-reserve-balance (delta-change int))
  (let (
    (current-reserve (var-get chainergy-total-reserve-amount))
    (updated-reserve (if (< delta-change 0)
                 (if (>= current-reserve (to-uint (- 0 delta-change)))
                     (- current-reserve (to-uint (- 0 delta-change)))
                     u0)
                 (+ current-reserve (to-uint delta-change)))))
    (asserts! (<= updated-reserve (var-get chainergy-reserve-cap-limit)) chainergy-err-reserve-exceeded-limit)
    (var-set chainergy-total-reserve-amount updated-reserve)
    (ok true)))

;; === Admin Controls ===

(define-public (chainergy-set-price-value (price-input uint))
  (begin
    (asserts! (is-eq tx-sender chainergy-admin-principal) chainergy-err-unauthorized-access)
    (asserts! (> price-input u0) chainergy-err-bad-price-value)
    (var-set chainergy-unit-price-amount price-input)
    (ok true)))

(define-public (chainergy-set-fee-rate (rate-input uint))
  (begin
    (asserts! (is-eq tx-sender chainergy-admin-principal) chainergy-err-unauthorized-access)
    (asserts! (<= rate-input u100) chainergy-err-bad-rate-value)
    (var-set chainergy-fee-rate-percentage rate-input)
    (ok true)))

(define-public (chainergy-set-refund-rate (rate-input uint))
  (begin
    (asserts! (is-eq tx-sender chainergy-admin-principal) chainergy-err-unauthorized-access)
    (asserts! (<= rate-input u100) chainergy-err-bad-rate-value)
    (var-set chainergy-refund-rate-percentage rate-input)
    (ok true)))

(define-public (chainergy-set-reserve-limit-cap (limit-input uint))
  (begin
    (asserts! (is-eq tx-sender chainergy-admin-principal) chainergy-err-unauthorized-access)
    (asserts! (>= limit-input (var-get chainergy-total-reserve-amount)) chainergy-err-bad-reserve-value)
    (var-set chainergy-reserve-cap-limit limit-input)
    (ok true)))

(define-public (chainergy-set-max-holdings-limit (max-input uint))
  (begin
    (asserts! (is-eq tx-sender chainergy-admin-principal) chainergy-err-unauthorized-access)
    (asserts! (> max-input u0) chainergy-err-bad-amount-value)
    (var-set chainergy-max-user-holdings-limit max-input)
    (ok true)))

;; === User Actions ===

(define-public (chainergy-list-units-for-sale (amount-input uint) (price-input uint))
  (let (
    (owned-energy-units (default-to u0 (map-get? chainergy-energy-holdings-map tx-sender)))
    (existing-listed-units (get units (default-to {units: u0, ask: u0} (map-get? chainergy-listings-market-map {seller: tx-sender}))))
    (total-listed-units (+ amount-input existing-listed-units)))
    (asserts! (> amount-input u0) chainergy-err-bad-amount-value)
    (asserts! (> price-input u0) chainergy-err-bad-price-value)
    (asserts! (>= owned-energy-units total-listed-units) chainergy-err-insufficient-funds-balance)
    (try! (chainergy-adjust-reserve-balance (to-int amount-input)))
    (map-set chainergy-listings-market-map {seller: tx-sender} {units: total-listed-units, ask: price-input})
    (ok true)))

(define-public (chainergy-unlist-units-from-sale (amount-input uint))
  (let (
    (on-market-units (get units (default-to {units: u0, ask: u0} (map-get? chainergy-listings-market-map {seller: tx-sender}))))
  )
    (asserts! (>= on-market-units amount-input) chainergy-err-insufficient-funds-balance)
    (try! (chainergy-adjust-reserve-balance (to-int (- amount-input))))
    (map-set chainergy-listings-market-map {seller: tx-sender}
             {units: (- on-market-units amount-input),
              ask: (get ask (default-to {units: u0, ask: u0} (map-get? chainergy-listings-market-map {seller: tx-sender})))})
    (ok true)))

(define-public (chainergy-buy-energy-units (from-seller principal) (units-to-buy uint))
  (let (
    (seller-offer-details (default-to {units: u0, ask: u0} (map-get? chainergy-listings-market-map {seller: from-seller})))
    (total-cost-amount (* units-to-buy (get ask seller-offer-details)))
    (transaction-fee-amount (chainergy-calc-fee-amount total-cost-amount))
    (total-payment-amount (+ total-cost-amount transaction-fee-amount))
    (seller-energy-balance (default-to u0 (map-get? chainergy-energy-holdings-map from-seller)))
    (buyer-stx-balance (default-to u0 (map-get? chainergy-stx-holdings-map tx-sender)))
    (seller-stx-balance (default-to u0 (map-get? chainergy-stx-holdings-map from-seller)))
    (contract-stx-balance (default-to u0 (map-get? chainergy-stx-holdings-map chainergy-admin-principal))))
    (asserts! (not (is-eq tx-sender from-seller)) chainergy-err-self-trade-attempt)
    (asserts! (> units-to-buy u0) chainergy-err-bad-amount-value)
    (asserts! (>= (get units seller-offer-details) units-to-buy) chainergy-err-insufficient-funds-balance)
    (asserts! (>= seller-energy-balance units-to-buy) chainergy-err-insufficient-funds-balance)
    (asserts! (>= buyer-stx-balance total-payment-amount) chainergy-err-insufficient-funds-balance)

    ;; Update balances
    (map-set chainergy-energy-holdings-map from-seller (- seller-energy-balance units-to-buy))
    (map-set chainergy-listings-market-map {seller: from-seller} {units: (- (get units seller-offer-details) units-to-buy), ask: (get ask seller-offer-details)})
    (map-set chainergy-stx-holdings-map tx-sender (- buyer-stx-balance total-payment-amount))
    (map-set chainergy-energy-holdings-map tx-sender (+ (default-to u0 (map-get? chainergy-energy-holdings-map tx-sender)) units-to-buy))
    (map-set chainergy-stx-holdings-map from-seller (+ seller-stx-balance total-cost-amount))
    (map-set chainergy-stx-holdings-map chainergy-admin-principal (+ contract-stx-balance transaction-fee-amount))
    (ok true)))

(define-public (chainergy-redeem-energy-units (units-to-redeem uint))
  (let (
    (owned-energy-balance (default-to u0 (map-get? chainergy-energy-holdings-map tx-sender)))
    (refund-payment-amount (chainergy-calc-refund-amount units-to-redeem))
    (contract-vault-balance (default-to u0 (map-get? chainergy-stx-holdings-map chainergy-admin-principal))))
    (asserts! (> units-to-redeem u0) chainergy-err-bad-amount-value)
    (asserts! (>= owned-energy-balance units-to-redeem) chainergy-err-insufficient-funds-balance)
    (asserts! (>= contract-vault-balance refund-payment-amount) chainergy-err-refund-failed-operation)
    (map-set chainergy-energy-holdings-map tx-sender (- owned-energy-balance units-to-redeem))
    (map-set chainergy-stx-holdings-map tx-sender (+ (default-to u0 (map-get? chainergy-stx-holdings-map tx-sender)) refund-payment-amount))
    (map-set chainergy-stx-holdings-map chainergy-admin-principal (- contract-vault-balance refund-payment-amount))
    (map-set chainergy-energy-holdings-map chainergy-admin-principal (+ (default-to u0 (map-get? chainergy-energy-holdings-map chainergy-admin-principal)) units-to-redeem))
    (try! (chainergy-adjust-reserve-balance (to-int (- units-to-redeem))))
    (ok true)))

;; === Read-only Views ===

(define-read-only (chainergy-get-price-info) (ok (var-get chainergy-unit-price-amount)))
(define-read-only (chainergy-get-fee-info) (ok (var-get chainergy-fee-rate-percentage)))
(define-read-only (chainergy-get-refund-info) (ok (var-get chainergy-refund-rate-percentage)))
(define-read-only (chainergy-get-owned-units (user-principal principal)) (ok (default-to u0 (map-get? chainergy-energy-holdings-map user-principal))))
(define-read-only (chainergy-get-stx-balance (user-principal principal)) (ok (default-to u0 (map-get? chainergy-stx-holdings-map user-principal))))
(define-read-only (chainergy-get-market-info (user-principal principal)) (ok (default-to {units: u0, ask: u0} (map-get? chainergy-listings-market-map {seller: user-principal}))))
(define-read-only (chainergy-get-user-limit) (ok (var-get chainergy-max-user-holdings-limit)))
(define-read-only (chainergy-get-reserve-status) (ok {used: (var-get chainergy-total-reserve-amount), cap: (var-get chainergy-reserve-cap-limit)}))