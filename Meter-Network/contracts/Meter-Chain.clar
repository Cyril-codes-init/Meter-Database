;; Smart Meter Data Management Contract
;; A robust contract for managing smart meter data with comprehensive features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_METER_NOT_FOUND (err u1001))
(define-constant ERR_INVALID_READING (err u1002))
(define-constant ERR_METER_ALREADY_EXISTS (err u1003))
(define-constant ERR_INVALID_TIMESTAMP (err u1004))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u1005))
(define-constant ERR_BILLING_ALREADY_PROCESSED (err u1006))
(define-constant ERR_METER_INACTIVE (err u1007))
(define-constant ERR_INVALID_RATE (err u1008))
(define-constant ERR_MAINTENANCE_MODE (err u1009))
(define-constant ERR_INVALID_THRESHOLD (err u1010))
(define-constant ERR_INVALID_INPUT (err u1011))

;; Data Variables
(define-data-var contract-active bool true)
(define-data-var maintenance-mode bool false)
(define-data-var base-rate uint u50) ;; Base rate per kWh in microSTX (0.00005 STX)
(define-data-var peak-rate uint u75) ;; Peak rate per kWh in microSTX (0.000075 STX)
(define-data-var total-meters-count uint u0)
(define-data-var total-readings-count uint u0)

;; Data Maps
(define-map smart-meters
  { meter-id: (string-ascii 32) }
  {
    owner: principal,
    location: (string-ascii 100),
    meter-type: (string-ascii 20),
    installation-date: uint,
    last-reading: uint,
    total-consumption: uint,
    status: (string-ascii 10), ;; "active", "inactive", "maintenance"
    tariff-plan: (string-ascii 20) ;; "standard", "peak", "economy"
  }
)

(define-map meter-readings
  { meter-id: (string-ascii 32), reading-id: uint }
  {
    timestamp: uint,
    consumption: uint,
    voltage: uint,
    current: uint,
    power-factor: uint,
    frequency: uint,
    reading-type: (string-ascii 15), ;; "regular", "peak", "off-peak"
    validator: principal
  }
)

(define-map meter-billing
  { meter-id: (string-ascii 32), billing-period: uint }
  {
    start-date: uint,
    end-date: uint,
    total-consumption: uint,
    peak-consumption: uint,
    off-peak-consumption: uint,
    base-charge: uint,
    consumption-charge: uint,
    total-amount: uint,
    payment-status: (string-ascii 10), ;; "pending", "paid", "overdue"
    payment-date: (optional uint)
  }
)

(define-map authorized-validators
  principal
  {
    name: (string-ascii 50),
    authorized: bool,
    validation-count: uint,
    join-date: uint
  }
)

(define-map meter-alerts
  { meter-id: (string-ascii 32), alert-id: uint }
  {
    alert-type: (string-ascii 20), ;; "high-usage", "tampering", "outage", "maintenance"
    message: (string-ascii 200),
    severity: (string-ascii 10), ;; "low", "medium", "high", "critical"
    timestamp: uint,
    resolved: bool,
    resolver: (optional principal)
  }
)

(define-map usage-thresholds
  { meter-id: (string-ascii 32) }
  {
    daily-limit: uint,
    monthly-limit: uint,
    peak-limit: uint,
    alert-threshold: uint
  }
)

;; Reading-only functions

;; Get meter information
(define-read-only (get-meter-info (meter-id (string-ascii 32)))
  (map-get? smart-meters { meter-id: meter-id })
)

;; Get specific reading
(define-read-only (get-meter-reading (meter-id (string-ascii 32)) (reading-id uint))
  (map-get? meter-readings { meter-id: meter-id, reading-id: reading-id })
)

;; Get billing information
(define-read-only (get-billing-info (meter-id (string-ascii 32)) (billing-period uint))
  (map-get? meter-billing { meter-id: meter-id, billing-period: billing-period })
)

;; Check if validator is authorized
(define-read-only (is-authorized-validator (validator principal))
  (match (map-get? authorized-validators validator)
    validator-data (get authorized validator-data)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-meters: (var-get total-meters-count),
    total-readings: (var-get total-readings-count),
    base-rate: (var-get base-rate),
    peak-rate: (var-get peak-rate),
    maintenance-mode: (var-get maintenance-mode),
    contract-active: (var-get contract-active)
  }
)

;; Get meter alerts
(define-read-only (get-meter-alert (meter-id (string-ascii 32)) (alert-id uint))
  (map-get? meter-alerts { meter-id: meter-id, alert-id: alert-id })
)

;; Get usage thresholds
(define-read-only (get-usage-thresholds (meter-id (string-ascii 32)))
  (map-get? usage-thresholds { meter-id: meter-id })
)

;; Calculate billing amount
(define-read-only (calculate-billing-amount 
  (consumption uint) 
  (peak-consumption uint) 
  (tariff-plan (string-ascii 20)))
  (let
    (
      (base-charge u100000) ;; Base charge: 0.1 STX in microSTX
      (rate (if (is-eq tariff-plan "peak") (var-get peak-rate) (var-get base-rate)))
      (peak-rate-val (var-get peak-rate))
      (consumption-charge (* consumption rate))
      (peak-charge (* peak-consumption peak-rate-val))
      (total-consumption-charge (+ consumption-charge peak-charge))
    )
    {
      base-charge: base-charge,
      consumption-charge: total-consumption-charge,
      total-amount: (+ base-charge total-consumption-charge)
    }
  )
)

;; Private functions

;; Validate meter ID format
(define-private (is-valid-meter-id (meter-id (string-ascii 32)))
  (and 
    (> (len meter-id) u0)
    (<= (len meter-id) u32)
  )
)

;; Validate location string
(define-private (is-valid-location (location (string-ascii 100)))
  (and 
    (> (len location) u0)
    (<= (len location) u100)
  )
)

;; Validate meter type
(define-private (is-valid-meter-type (meter-type (string-ascii 20)))
  (and 
    (> (len meter-type) u0)
    (<= (len meter-type) u20)
  )
)

;; Validate tariff plan
(define-private (is-valid-tariff-plan (tariff-plan (string-ascii 20)))
  (or (is-eq tariff-plan "standard") 
      (or (is-eq tariff-plan "peak") (is-eq tariff-plan "economy")))
)

;; Validate reading type
(define-private (is-valid-reading-type (reading-type (string-ascii 15)))
  (or (is-eq reading-type "regular") 
      (or (is-eq reading-type "peak") (is-eq reading-type "off-peak")))
)

;; Validate meter status
(define-private (is-valid-meter-status (status (string-ascii 10)))
  (or (is-eq status "active") 
      (or (is-eq status "inactive") (is-eq status "maintenance")))
)

;; Validate validator name
(define-private (is-valid-validator-name (name (string-ascii 50)))
  (and 
    (> (len name) u0)
    (<= (len name) u50)
  )
)

;; Validate validator principal
(define-private (is-valid-validator-principal (validator principal))
  (and 
    (not (is-eq validator CONTRACT_OWNER)) ;; Validator cannot be contract owner
    (not (is-eq validator 'SP000000000000000000002Q6VF78)) ;; Not zero principal
  )
)

;; Validate power factor (should be between 0 and 100 representing percentage)
(define-private (is-valid-power-factor (power-factor uint))
  (<= power-factor u100)
)

;; Validate frequency (should be around 50-60 Hz, represented as uint)
(define-private (is-valid-frequency (frequency uint))
  (and (>= frequency u45) (<= frequency u65))
)

;; Validate consumption values
(define-private (is-valid-consumption (consumption uint))
  (and (> consumption u0) (<= consumption u1000000)) ;; Max 1M units
)

;; Check if meter exists and is active
(define-private (is-meter-active (meter-id (string-ascii 32)))
  (match (map-get? smart-meters { meter-id: meter-id })
    meter (is-eq (get status meter) "active")
    false
  )
)

;; Check if caller is meter owner
(define-private (is-meter-owner (meter-id (string-ascii 32)) (caller principal))
  (match (map-get? smart-meters { meter-id: meter-id })
    meter (is-eq (get owner meter) caller)
    false
  )
)

;; Validate reading data
(define-private (is-valid-reading (consumption uint) (voltage uint) (current uint))
  (and 
    (is-valid-consumption consumption)
    (and (>= voltage u200) (<= voltage u250)) ;; Voltage range 200-250V
    (and (>= current u1) (<= current u100))   ;; Current range 1-100A
  )
)

;; Check usage against thresholds
(define-private (check-usage-threshold (meter-id (string-ascii 32)) (consumption uint))
  (match (map-get? usage-thresholds { meter-id: meter-id })
    thresholds
      (if (>= consumption (get alert-threshold thresholds))
        (let
          (
            (alert-result (create-alert meter-id "high-usage" "Consumption exceeds threshold" "medium"))
          )
          true ;; Always return true regardless of alert creation result
        )
        true
      )
    true
  )
)

;; Data variable to track alert IDs
(define-data-var next-alert-id uint u1)

;; Create an alert (private helper)
(define-private (create-alert 
  (meter-id (string-ascii 32)) 
  (alert-type (string-ascii 20)) 
  (message (string-ascii 200)) 
  (severity (string-ascii 10)))
  (let
    (
      (alert-id (var-get next-alert-id))
    )
    (map-set meter-alerts 
      { meter-id: meter-id, alert-id: alert-id }
      {
        alert-type: alert-type,
        message: message,
        severity: severity,
        timestamp: stacks-block-height,
        resolved: false,
        resolver: none
      }
    )
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)
  )
)

;; Public functions

;; Register a new smart meter
(define-public (register-meter 
  (meter-id (string-ascii 32))
  (location (string-ascii 100))
  (meter-type (string-ascii 20))
  (tariff-plan (string-ascii 20)))
  (begin
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-location location) ERR_INVALID_INPUT)
    (asserts! (is-valid-meter-type meter-type) ERR_INVALID_INPUT)
    (asserts! (is-valid-tariff-plan tariff-plan) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? smart-meters { meter-id: meter-id })) ERR_METER_ALREADY_EXISTS)
    
    (map-set smart-meters { meter-id: meter-id }
      {
        owner: tx-sender,
        location: location,
        meter-type: meter-type,
        installation-date: stacks-block-height,
        last-reading: u0,
        total-consumption: u0,
        status: "active",
        tariff-plan: tariff-plan
      }
    )
    
    ;; Set default thresholds
    (map-set usage-thresholds { meter-id: meter-id }
      {
        daily-limit: u1000,
        monthly-limit: u30000,
        peak-limit: u500,
        alert-threshold: u800
      }
    )
    
    (var-set total-meters-count (+ (var-get total-meters-count) u1))
    (ok meter-id)
  )
)

;; Add a new meter reading (only by authorized validators)
(define-public (add-meter-reading
  (meter-id (string-ascii 32))
  (consumption uint)
  (voltage uint)
  (current uint)
  (power-factor uint)
  (frequency uint)
  (reading-type (string-ascii 15)))
  (let
    (
      (reading-id (+ (var-get total-readings-count) u1))
      (meter-info (unwrap! (map-get? smart-meters { meter-id: meter-id }) ERR_METER_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (not (var-get maintenance-mode)) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-power-factor power-factor) ERR_INVALID_INPUT)
    (asserts! (is-valid-frequency frequency) ERR_INVALID_INPUT)
    (asserts! (is-valid-reading-type reading-type) ERR_INVALID_INPUT)
    (asserts! (is-authorized-validator tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-meter-active meter-id) ERR_METER_INACTIVE)
    (asserts! (is-valid-reading consumption voltage current) ERR_INVALID_READING)
    
    ;; Check usage thresholds
    (asserts! (check-usage-threshold meter-id consumption) ERR_INVALID_READING)
    
    ;; Add the reading
    (map-set meter-readings 
      { meter-id: meter-id, reading-id: reading-id }
      {
        timestamp: stacks-block-height,
        consumption: consumption,
        voltage: voltage,
        current: current,
        power-factor: power-factor,
        frequency: frequency,
        reading-type: reading-type,
        validator: tx-sender
      }
    )
    
    ;; Update meter info
    (map-set smart-meters { meter-id: meter-id }
      (merge meter-info {
        last-reading: reading-id,
        total-consumption: (+ (get total-consumption meter-info) consumption)
      })
    )
    
    ;; Update validator stats
    (match (map-get? authorized-validators tx-sender)
      validator-info
        (map-set authorized-validators tx-sender
          (merge validator-info {
            validation-count: (+ (get validation-count validator-info) u1)
          })
        )
      false ;; This should not happen due to authorization check above
    )
    
    (var-set total-readings-count reading-id)
    (ok reading-id)
  )
)

;; Process billing for a meter
(define-public (process-billing
  (meter-id (string-ascii 32))
  (billing-period uint)
  (start-date uint)
  (end-date uint)
  (total-consumption uint)
  (peak-consumption uint)
  (off-peak-consumption uint))
  (let
    (
      (meter-info (unwrap! (map-get? smart-meters { meter-id: meter-id }) ERR_METER_NOT_FOUND))
      (billing-calc (calculate-billing-amount total-consumption peak-consumption (get tariff-plan meter-info)))
    )
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (> billing-period u0) ERR_INVALID_INPUT)
    (asserts! (is-valid-consumption total-consumption) ERR_INVALID_INPUT)
    (asserts! (is-valid-consumption peak-consumption) ERR_INVALID_INPUT)
    (asserts! (is-valid-consumption off-peak-consumption) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-meter-owner meter-id tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (< start-date end-date) ERR_INVALID_TIMESTAMP)
    (asserts! (is-none (map-get? meter-billing { meter-id: meter-id, billing-period: billing-period })) 
              ERR_BILLING_ALREADY_PROCESSED)
    
    (map-set meter-billing 
      { meter-id: meter-id, billing-period: billing-period }
      {
        start-date: start-date,
        end-date: end-date,
        total-consumption: total-consumption,
        peak-consumption: peak-consumption,
        off-peak-consumption: off-peak-consumption,
        base-charge: (get base-charge billing-calc),
        consumption-charge: (get consumption-charge billing-calc),
        total-amount: (get total-amount billing-calc),
        payment-status: "pending",
        payment-date: none
      }
    )
    
    (ok (get total-amount billing-calc))
  )
)

;; Pay meter bill
(define-public (pay-meter-bill
  (meter-id (string-ascii 32))
  (billing-period uint)
  (amount uint))
  (let
    (
      (billing-info (unwrap! (map-get? meter-billing { meter-id: meter-id, billing-period: billing-period }) 
                             ERR_BILLING_ALREADY_PROCESSED))
      (meter-info (unwrap! (map-get? smart-meters { meter-id: meter-id }) ERR_METER_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (> billing-period u0) ERR_INVALID_INPUT)
    (asserts! (is-meter-owner meter-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= amount (get total-amount billing-info)) ERR_INSUFFICIENT_PAYMENT)
    (asserts! (is-eq (get payment-status billing-info) "pending") ERR_BILLING_ALREADY_PROCESSED)
    
    ;; Transfer payment to contract owner
    (try! (stx-transfer? amount tx-sender CONTRACT_OWNER))
    
    ;; Update billing status
    (map-set meter-billing 
      { meter-id: meter-id, billing-period: billing-period }
      (merge billing-info {
        payment-status: "paid",
        payment-date: (some stacks-block-height)
      })
    )
    
    (ok true)
  )
)

;; Update meter status
(define-public (update-meter-status 
  (meter-id (string-ascii 32)) 
  (new-status (string-ascii 10)))
  (let
    (
      (meter-info (unwrap! (map-get? smart-meters { meter-id: meter-id }) ERR_METER_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (is-valid-meter-status new-status) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-meter-owner meter-id tx-sender)) ERR_UNAUTHORIZED)
    
    (map-set smart-meters { meter-id: meter-id }
      (merge meter-info { status: new-status })
    )
    
    (ok true)
  )
)

;; Add authorized validator (only contract owner)
(define-public (add-authorized-validator 
  (validator principal) 
  (name (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-validator-principal validator) ERR_INVALID_INPUT)
    (asserts! (is-valid-validator-name name) ERR_INVALID_INPUT)
    
    (map-set authorized-validators validator
      {
        name: name,
        authorized: true,
        validation-count: u0,
        join-date: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; Remove authorized validator (only contract owner)
(define-public (remove-authorized-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-validator-principal validator) ERR_INVALID_INPUT)
    
    (match (map-get? authorized-validators validator)
      validator-info
        (begin
          (map-set authorized-validators validator
            (merge validator-info { authorized: false })
          )
          (ok true)
        )
      ERR_UNAUTHORIZED
    )
  )
)

;; Update usage thresholds
(define-public (update-usage-thresholds
  (meter-id (string-ascii 32))
  (daily-limit uint)
  (monthly-limit uint)
  (peak-limit uint)
  (alert-threshold uint))
  (begin
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-meter-owner meter-id tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (and (> daily-limit u0) (> monthly-limit u0) (> peak-limit u0) (> alert-threshold u0)) 
              ERR_INVALID_THRESHOLD)
    (asserts! (is-some (map-get? smart-meters { meter-id: meter-id })) ERR_METER_NOT_FOUND)
    
    (map-set usage-thresholds { meter-id: meter-id }
      {
        daily-limit: daily-limit,
        monthly-limit: monthly-limit,
        peak-limit: peak-limit,
        alert-threshold: alert-threshold
      }
    )
    
    (ok true)
  )
)

;; Resolve alert
(define-public (resolve-alert 
  (meter-id (string-ascii 32)) 
  (alert-id uint))
  (let
    (
      (alert-info (unwrap! (map-get? meter-alerts { meter-id: meter-id, alert-id: alert-id }) 
                           ERR_METER_NOT_FOUND))
    )
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (is-valid-meter-id meter-id) ERR_INVALID_INPUT)
    (asserts! (> alert-id u0) ERR_INVALID_INPUT)
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) 
                  (is-meter-owner meter-id tx-sender)
                  (is-authorized-validator tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get resolved alert-info)) ERR_BILLING_ALREADY_PROCESSED)
    
    (map-set meter-alerts 
      { meter-id: meter-id, alert-id: alert-id }
      (merge alert-info {
        resolved: true,
        resolver: (some tx-sender)
      })
    )
    
    (ok true)
  )
)

;; Administrative functions (only contract owner)

;; Update rates
(define-public (update-rates (new-base-rate uint) (new-peak-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    (asserts! (and (> new-base-rate u0) (> new-peak-rate u0)) ERR_INVALID_RATE)
    
    (var-set base-rate new-base-rate)
    (var-set peak-rate new-peak-rate)
    (ok true)
  )
)

;; Toggle maintenance mode
(define-public (toggle-maintenance-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (var-get contract-active) ERR_MAINTENANCE_MODE)
    
    (var-set maintenance-mode (not (var-get maintenance-mode)))
    (ok (var-get maintenance-mode))
  )
)

;; Emergency pause contract
(define-public (emergency-pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (var-set contract-active false)
    (var-set maintenance-mode true)
    (ok true)
  )
)

;; Reactivate contract
(define-public (reactivate-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    (var-set contract-active true)
    (var-set maintenance-mode false)
    (ok true)
  )
)