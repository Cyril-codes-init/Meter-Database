# Smart Meter Data Management Contract

## Overview

A comprehensive Clarity smart contract for managing smart meter data on the Stacks blockchain. This contract provides robust functionality for meter registration, reading collection, billing management, and administrative oversight with built-in security features and validation mechanisms.

## Features

### Core Functionality
- **Meter Registration**: Register new smart meters with owner authentication
- **Reading Management**: Collect and validate meter readings from authorized validators
- **Billing System**: Process bills with configurable tariff plans and payment tracking
- **Alert System**: Monitor usage thresholds and generate alerts
- **Multi-tier Authorization**: Contract owner, meter owners, and authorized validators

### Tariff Plans
- **Standard**: Base rate billing
- **Peak**: Higher rate during peak hours
- **Economy**: Cost-effective plan for off-peak usage

### Security Features
- Contract pause/resume functionality
- Maintenance mode for system updates
- Input validation and error handling
- Authorized validator system

## Contract Structure

### Constants
```clarity
ERR_UNAUTHORIZED (u1000)
ERR_METER_NOT_FOUND (u1001)
ERR_INVALID_READING (u1002)
ERR_METER_ALREADY_EXISTS (u1003)
ERR_INVALID_TIMESTAMP (u1004)
ERR_INSUFFICIENT_PAYMENT (u1005)
ERR_BILLING_ALREADY_PROCESSED (u1006)
ERR_METER_INACTIVE (u1007)
ERR_INVALID_RATE (u1008)
ERR_MAINTENANCE_MODE (u1009)
ERR_INVALID_THRESHOLD (u1010)
ERR_INVALID_INPUT (u1011)
```

### Data Variables
- `contract-active`: Contract operational status
- `maintenance-mode`: Maintenance flag for system updates
- `base-rate`: Standard billing rate (microSTX per kWh)
- `peak-rate`: Peak hour billing rate (microSTX per kWh)
- `total-meters-count`: Total registered meters
- `total-readings-count`: Total recorded readings

## Public Functions

### Meter Management

#### `register-meter`
Register a new smart meter in the system.

**Parameters:**
- `meter-id` (string-ascii 32): Unique meter identifier
- `location` (string-ascii 100): Physical location of the meter
- `meter-type` (string-ascii 20): Type of meter (e.g., "residential", "commercial")
- `tariff-plan` (string-ascii 20): Billing plan ("standard", "peak", "economy")

**Returns:** `(response string-ascii err)`

**Usage:**
```clarity
(contract-call? .smart-meter-contract register-meter 
  "METER001" 
  "123 Main St, Apt 4B" 
  "residential" 
  "standard")
```

#### `update-meter-status`
Update the operational status of a meter.

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `new-status` (string-ascii 10): New status ("active", "inactive", "maintenance")

**Authorization:** Contract owner or meter owner

### Reading Management

#### `add-meter-reading`
Add a new meter reading (authorized validators only).

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `consumption` (uint): Energy consumption in kWh
- `voltage` (uint): Voltage reading (200-250V)
- `current` (uint): Current reading (1-100A)
- `power-factor` (uint): Power factor (0-100%)
- `frequency` (uint): Frequency reading (45-65Hz)
- `reading-type` (string-ascii 15): Type ("regular", "peak", "off-peak")

**Authorization:** Authorized validators only

### Billing Management

#### `process-billing`
Generate billing information for a specific period.

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `billing-period` (uint): Billing period identifier
- `start-date` (uint): Period start date (block height)
- `end-date` (uint): Period end date (block height)
- `total-consumption` (uint): Total energy consumed
- `peak-consumption` (uint): Peak hour consumption
- `off-peak-consumption` (uint): Off-peak consumption

**Authorization:** Contract owner or meter owner

#### `pay-meter-bill`
Process payment for a meter bill.

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `billing-period` (uint): Billing period identifier
- `amount` (uint): Payment amount in microSTX

**Authorization:** Meter owner only

### Threshold Management

#### `update-usage-thresholds`
Configure usage monitoring thresholds for a meter.

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `daily-limit` (uint): Daily usage limit
- `monthly-limit` (uint): Monthly usage limit
- `peak-limit` (uint): Peak hour limit
- `alert-threshold` (uint): Alert trigger threshold

**Authorization:** Contract owner or meter owner

### Alert Management

#### `resolve-alert`
Mark an alert as resolved.

**Parameters:**
- `meter-id` (string-ascii 32): Meter identifier
- `alert-id` (uint): Alert identifier

**Authorization:** Contract owner, meter owner, or authorized validator

## Read-Only Functions

### `get-meter-info`
Retrieve comprehensive meter information.

### `get-meter-reading`
Get specific reading data.

### `get-billing-info`
Retrieve billing information for a specific period.

### `is-authorized-validator`
Check if a principal is an authorized validator.

### `get-contract-stats`
Get overall contract statistics.

### `calculate-billing-amount`
Calculate billing amount based on consumption and tariff plan.

## Administrative Functions (Contract Owner Only)

### `add-authorized-validator`
Add a new authorized validator to the system.

### `remove-authorized-validator`
Remove authorization from a validator.

### `update-rates`
Update base and peak billing rates.

### `toggle-maintenance-mode`
Enable/disable maintenance mode.

### `emergency-pause`
Emergency contract pause functionality.

### `reactivate-contract`
Reactivate a paused contract.

## Usage Examples

### Basic Meter Registration
```clarity
;; Register a residential meter
(contract-call? .smart-meter-contract register-meter 
  "RES001" 
  "456 Oak Avenue" 
  "residential" 
  "standard")
```

### Adding a Reading (Validator)
```clarity
;; Add a regular reading
(contract-call? .smart-meter-contract add-meter-reading
  "RES001"
  u150    ;; 150 kWh consumption
  u230    ;; 230V voltage
  u15     ;; 15A current
  u95     ;; 95% power factor
  u50     ;; 50Hz frequency
  "regular")
```

### Processing Billing
```clarity
;; Process monthly billing
(contract-call? .smart-meter-contract process-billing
  "RES001"
  u202501  ;; January 2025
  u1000    ;; Start block
  u1500    ;; End block
  u500     ;; Total consumption
  u100     ;; Peak consumption
  u400)    ;; Off-peak consumption
```

## Error Handling

The contract implements comprehensive error handling with specific error codes:

- **ERR_UNAUTHORIZED**: Insufficient permissions
- **ERR_METER_NOT_FOUND**: Meter does not exist
- **ERR_INVALID_READING**: Reading data validation failed
- **ERR_METER_ALREADY_EXISTS**: Duplicate meter registration
- **ERR_MAINTENANCE_MODE**: Contract in maintenance mode

## Security Considerations

1. **Authorization Levels**: Three-tier system (owner, meter owners, validators)
2. **Input Validation**: Comprehensive validation for all inputs
3. **State Management**: Proper contract state management with pause functionality
4. **Payment Security**: STX transfer validation and amount verification