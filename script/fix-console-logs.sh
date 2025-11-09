#!/bin/bash
# Fix console.log calls to use string.concat

sed -i '' \
  -e 's/console\.log("Vault Total Assets:", \(.*\), "USDC")/console.log(string.concat("Vault Total Assets: ", Strings.toString(\1), " USDC"))/g' \
  -e 's/console\.log("Vault Total Shares:", \(.*\))/console.log(string.concat("Vault Total Shares: ", Strings.toString(\1)))/g' \
  -e 's/console\.log("User1 USDC Balance:", \(.*\), "USDC")/console.log(string.concat("User1 USDC Balance: ", Strings.toString(\1), " USDC"))/g' \
  src/test/vaults/AaveEarnVaultTest.t.sol

