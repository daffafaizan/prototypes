# Musical Charts

## Overview
**Musical Charts** work on creating an Automated Market Maker (AMM) where people can swap tokens only after listening to music. Users experience market trends through AI generated violin music, and they are allowed to make a trade signal after they have listened to the generated music. The project is more fun because each trade triggers a new violin melody based on the market data, ensuring a fresh and engaging experience every time for the user.

## Problem
Price data of any token or memecoin alone is not engaging to a general user and often user doesn't feel the thrill or enjoyment while trading these coins. 

## Insight
Restricting financial signals of buy/sell through music can foster a more intuitive and emotional connection to market trends.

## Solution
Encrypt and process real-time price data in a *Trusted Execution Environment* (TEE) to generate violin compositions, allowing users to ‘listen’ to market changes before they swap.

## Goals
Focus on engagement and excitement rather than commercial viability, providing a unique, shareable experience.

## Get Involved
Join us in redefining data engagement and creating a fun trading experience through sound!

## Usage

### Build

```shell
$ sforge build
```

### Test

```shell
$ sforge test
```

### Format

```shell
$ sforge fmt
```

### Gas Snapshots

```shell
$ sforge snapshot
```

### Anvil

```shell
$ sanvil
```

### Deploy

```shell
$ sforge script script/ViolinAMM.s.sol:ViolinAMMScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Help

```shell
$ sforge --help
$ sanvil --help
```
