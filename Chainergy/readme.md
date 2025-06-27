# Chainergy - Decentralized Energy Trading Smart Contract

A Clarity smart contract for decentralized energy trading on the Stacks blockchain. Chainergy enables peer-to-peer energy unit trading with built-in marketplace functionality, admin controls, and reserve management.

## Overview

Chainergy facilitates the trading of energy units between users through a decentralized marketplace. Users can list energy units for sale, purchase from other users, and redeem energy units back to the contract for STX tokens.

## Features

- **Energy Unit Trading**: Buy and sell energy units between users
- **Marketplace Listings**: List energy units at custom prices
- **Reserve Management**: Built-in reserve system with configurable limits
- **Fee System**: Configurable transaction fees for platform sustainability
- **Refund Mechanism**: Redeem energy units back to the contract
- **Admin Controls**: Administrative functions for system management

## Contract Architecture

### Constants

- **Admin Principal**: Contract deployer has administrative privileges
- **Error Codes**: Comprehensive error handling (100-109)

### Global State Variables

- `chainergy-unit-price-amount`: Base price per energy unit (default: 100)
- `chainergy-max-user-holdings-limit`: Maximum units a user can hold (default: 10,000)
- `chainergy-fee-rate-percentage`: Transaction fee percentage (default: 5%)
- `chainergy-refund-rate-percentage`: Refund rate when redeeming (default: 90%)
- `chainergy-reserve-cap-limit`: Maximum reserve capacity (default: 1,000,000)
- `chainergy-total-reserve-amount`: Current reserve amount (default: 0)

### Data Maps

- `chainergy-energy-holdings-map`: Tracks energy unit balances per user
- `chainergy-stx-holdings-map`: Tracks STX token balances per user
- `chainergy-listings-market-map`: Active marketplace listings

## Functions

### Admin Functions

#### `chainergy-set-price-value`
```clarity
(chainergy-set-price-value (price-input uint))
```
Sets the base unit price for energy units.

#### `chainergy-set-fee-rate`
```clarity
(chainergy-set-fee-rate (rate-input uint))
```
Sets the transaction fee rate (0-100%).

#### `chainergy-set-refund-rate`
```clarity
(chainergy-set-refund-rate (rate-input uint))
```
Sets the refund rate for energy unit redemption (0-100%).

#### `chainergy-set-reserve-limit-cap`
```clarity
(chainergy-set-reserve-limit-cap (limit-input uint))
```
Sets the maximum reserve capacity.

#### `chainergy-set-max-holdings-limit`
```clarity
(chainergy-set-max-holdings-limit (max-input uint))
```
Sets the maximum energy units a user can hold.

### User Functions

#### `chainergy-list-units-for-sale`
```clarity
(chainergy-list-units-for-sale (amount-input uint) (price-input uint))
```
Lists energy units for sale at a specified price.

**Parameters:**
- `amount-input`: Number of energy units to list
- `price-input`: Price per unit in STX

**Requirements:**
- User must own enough energy units
- Amount and price must be greater than 0
- Reserve capacity must not be exceeded

#### `chainergy-unlist-units-from-sale`
```clarity
(chainergy-unlist-units-from-sale (amount-input uint))
```
Removes energy units from marketplace listing.

**Parameters:**
- `amount-input`: Number of units to unlist

#### `chainergy-buy-energy-units`
```clarity
(chainergy-buy-energy-units (from-seller principal) (units-to-buy uint))
```
Purchases energy units from another user.

**Parameters:**
- `from-seller`: Principal address of the seller
- `units-to-buy`: Number of units to purchase

**Requirements:**
- Buyer cannot purchase from themselves
- Seller must have sufficient units listed
- Buyer must have sufficient STX balance (including fees)

#### `chainergy-redeem-energy-units`
```clarity
(chainergy-redeem-energy-units (units-to-redeem uint))
```
Redeems energy units back to the contract for STX tokens.

**Parameters:**
- `units-to-redeem`: Number of units to redeem

**Returns:** STX tokens based on current refund rate

### Read-Only Functions

#### `chainergy-get-price-info`
Returns the current base unit price.

#### `chainergy-get-fee-info`
Returns the current transaction fee rate.

#### `chainergy-get-refund-info`
Returns the current refund rate.

#### `chainergy-get-owned-units`
```clarity
(chainergy-get-owned-units (user-principal principal))
```
Returns the energy unit balance for a user.

#### `chainergy-get-stx-balance`
```clarity
(chainergy-get-stx-balance (user-principal principal))
```
Returns the STX token balance for a user.

#### `chainergy-get-market-info`
```clarity
(chainergy-get-market-info (user-principal principal))
```
Returns marketplace listing information for a user.

#### `chainergy-get-user-limit`
Returns the maximum holdings limit per user.

#### `chainergy-get-reserve-status`
Returns current reserve usage and capacity.

## Usage Examples

### Listing Energy Units
```clarity
;; List 100 energy units at 150 STX per unit
(contract-call? .chainergy chainergy-list-units-for-sale u100 u150)
```

### Buying Energy Units
```clarity
;; Buy 50 units from a specific seller
(contract-call? .chainergy chainergy-buy-energy-units 'ST1SELLER... u50)
```

### Redeeming Energy Units
```clarity
;; Redeem 25 units back to the contract
(contract-call? .chainergy chainergy-redeem-energy-units u25)
```

## Error Codes

- `u100`: Unauthorized access
- `u101`: Insufficient funds/balance
- `u102`: Transfer failed
- `u103`: Invalid price value
- `u104`: Invalid amount value
- `u105`: Invalid rate value
- `u106`: Refund operation failed
- `u107`: Self-trade attempt
- `u108`: Reserve limit exceeded
- `u109`: Invalid reserve value

## Reserve System

The reserve system tracks the total amount of energy units actively listed in the marketplace. This helps maintain system stability and prevents over-listing of units.

- **Reserve Cap**: Maximum total units that can be listed
- **Reserve Tracking**: Automatically adjusts when units are listed/unlisted
- **Reserve Protection**: Prevents listings that would exceed capacity

## Fee Structure

- **Transaction Fees**: Applied to all purchases (default 5%)
- **Fee Distribution**: Fees are collected by the contract admin
- **Refund Rate**: Partial refund when redeeming units (default 90%)

## Security Features

- **Admin-only Controls**: Critical system parameters can only be modified by admin
- **Self-trade Prevention**: Users cannot trade with themselves
- **Balance Verification**: All transactions verify sufficient balances
- **Reserve Management**: Prevents system overload through reserve caps

## Development

### Prerequisites
- Stacks CLI
- Clarinet (for testing)

### Testing
```bash
clarinet test
```

### Deployment
```bash
stacks deploy chainergy.clar
```
