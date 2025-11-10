;; LaserQuality Supply Chain Quality Assurance Contract
;; Predictive quality tracking and automated compliance management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-score (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-insufficient-stake (err u105))

;; Minimum stake required for validators (in microSTX)
(define-constant min-validator-stake u1000000)

;; Data Variables
(define-data-var platform-active bool true)

;; Data Maps

;; Product quality tracking
(define-map products
  { product-id: (string-ascii 64) }
  {
    owner: principal,
    quality-score: uint,
    last-updated: uint,
    industry: (string-ascii 32),
    compliance-status: bool,
    total-predictions: uint
  }
)

;; Validator nodes with staking
(define-map validators
  { validator: principal }
  {
    stake-amount: uint,
    accuracy-score: uint,
    total-validations: uint,
    industry-expertise: (string-ascii 32),
    active: bool
  }
)

;; Quality predictions
(define-map quality-predictions
  { product-id: (string-ascii 64), validator: principal }
  {
    predicted-score: uint,
    timestamp: uint,
    actual-score: uint,
    resolved: bool
  }
)

;; IoT sensor data
(define-map sensor-readings
  { product-id: (string-ascii 64), reading-id: uint }
  {
    temperature: int,
    humidity: uint,
    timestamp: uint,
    location: (string-ascii 64)
  }
)

;; Compliance audit trails
(define-map audit-logs
  { product-id: (string-ascii 64), log-id: uint }
  {
    auditor: principal,
    timestamp: uint,
    compliance-hash: (buff 32),
    passed: bool
  }
)

;; Quality marketplace listings
(define-map supplier-listings
  { supplier: principal }
  {
    avg-quality-score: uint,
    total-products: uint,
    premium-tier: bool
  }
)

;; Read-only functions

(define-read-only (get-product-info (product-id (string-ascii 64)))
  (map-get? products { product-id: product-id })
)

(define-read-only (get-validator-info (validator principal))
  (map-get? validators { validator: validator })
)

(define-read-only (get-quality-prediction (product-id (string-ascii 64)) (validator principal))
  (map-get? quality-predictions { product-id: product-id, validator: validator })
)

(define-read-only (get-sensor-reading (product-id (string-ascii 64)) (reading-id uint))
  (map-get? sensor-readings { product-id: product-id, reading-id: reading-id })
)

(define-read-only (get-audit-log (product-id (string-ascii 64)) (log-id uint))
  (map-get? audit-logs { product-id: product-id, log-id: log-id })
)

(define-read-only (get-supplier-listing (supplier principal))
  (map-get? supplier-listings { supplier: supplier })
)

(define-read-only (is-platform-active)
  (ok (var-get platform-active))
)

;; Public functions

;; Register a new product
(define-public (register-product 
  (product-id (string-ascii 64))
  (industry (string-ascii 32))
  (initial-score uint))
  (begin
    (asserts! (var-get platform-active) err-unauthorized)
    (asserts! (<= initial-score u100) err-invalid-score)
    (asserts! (is-none (map-get? products { product-id: product-id })) err-already-exists)
    (ok (map-set products
      { product-id: product-id }
      {
        owner: tx-sender,
        quality-score: initial-score,
        last-updated: block-height,
        industry: industry,
        compliance-status: true,
        total-predictions: u0
      }
    ))
  )
)

;; Register as a validator with stake
(define-public (register-validator (industry-expertise (string-ascii 32)))
  (let ((stake-amount min-validator-stake))
    (begin
      (asserts! (var-get platform-active) err-unauthorized)
      (asserts! (>= stake-amount min-validator-stake) err-insufficient-stake)
      (asserts! (is-none (map-get? validators { validator: tx-sender })) err-already-exists)
      (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
      (ok (map-set validators
        { validator: tx-sender }
        {
          stake-amount: stake-amount,
          accuracy-score: u100,
          total-validations: u0,
          industry-expertise: industry-expertise,
          active: true
        }
      ))
    )
  )
)

;; Submit quality prediction
(define-public (submit-prediction 
  (product-id (string-ascii 64))
  (predicted-score uint))
  (let ((validator-info (unwrap! (map-get? validators { validator: tx-sender }) err-unauthorized)))
    (begin
      (asserts! (var-get platform-active) err-unauthorized)
      (asserts! (get active validator-info) err-unauthorized)
      (asserts! (<= predicted-score u100) err-invalid-score)
      (asserts! (is-some (map-get? products { product-id: product-id })) err-not-found)
      (ok (map-set quality-predictions
        { product-id: product-id, validator: tx-sender }
        {
          predicted-score: predicted-score,
          timestamp: block-height,
          actual-score: u0,
          resolved: false
        }
      ))
    )
  )
)

;; Update product quality score
(define-public (update-quality-score 
  (product-id (string-ascii 64))
  (new-score uint))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) err-not-found)))
    (begin
      (asserts! (var-get platform-active) err-unauthorized)
      (asserts! (is-eq tx-sender (get owner product)) err-unauthorized)
      (asserts! (<= new-score u100) err-invalid-score)
      (ok (map-set products
        { product-id: product-id }
        (merge product {
          quality-score: new-score,
          last-updated: block-height
        })
      ))
    )
  )
)

;; Record IoT sensor data
(define-public (record-sensor-data
  (product-id (string-ascii 64))
  (reading-id uint)
  (temperature int)
  (humidity uint)
  (location (string-ascii 64)))
  (begin
    (asserts! (var-get platform-active) err-unauthorized)
    (asserts! (is-some (map-get? products { product-id: product-id })) err-not-found)
    (ok (map-set sensor-readings
      { product-id: product-id, reading-id: reading-id }
      {
        temperature: temperature,
        humidity: humidity,
        timestamp: block-height,
        location: location
      }
    ))
  )
)

;; Create audit log entry
(define-public (create-audit-log
  (product-id (string-ascii 64))
  (log-id uint)
  (compliance-hash (buff 32))
  (passed bool))
  (begin
    (asserts! (var-get platform-active) err-unauthorized)
    (asserts! (is-some (map-get? products { product-id: product-id })) err-not-found)
    (ok (map-set audit-logs
      { product-id: product-id, log-id: log-id }
      {
        auditor: tx-sender,
        timestamp: block-height,
        compliance-hash: compliance-hash,
        passed: passed
      }
    ))
  )
)

;; Update supplier listing
(define-public (update-supplier-listing
  (avg-score uint)
  (product-count uint))
  (begin
    (asserts! (var-get platform-active) err-unauthorized)
    (asserts! (<= avg-score u100) err-invalid-score)
    (ok (map-set supplier-listings
      { supplier: tx-sender }
      {
        avg-quality-score: avg-score,
        total-products: product-count,
        premium-tier: (>= avg-score u90)
      }
    ))
  )
)

;; Update compliance status
(define-public (update-compliance-status
  (product-id (string-ascii 64))
  (status bool))
  (let ((product (unwrap! (map-get? products { product-id: product-id }) err-not-found)))
    (begin
      (asserts! (var-get platform-active) err-unauthorized)
      (asserts! (is-eq tx-sender (get owner product)) err-unauthorized)
      (ok (map-set products
        { product-id: product-id }
        (merge product { compliance-status: status })
      ))
    )
  )
)

;; Admin functions

(define-public (toggle-platform-status)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set platform-active (not (var-get platform-active))))
  )
)