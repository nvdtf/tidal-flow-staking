import "FungibleToken"
import "FlowToken"
import "TidalYield"

/// Transaction to withdraw funds from a Strategy
transaction(amount: UFix64) {
    prepare(user: auth(Storage) &Account) {
        // Borrow from storage
        let strategyRef = user.storage.borrow<auth(FungibleToken.Withdraw) &{TidalYield.Strategy}>(from: /storage/LiquidStakingStrategy)!

        // Withdraw from the Strategy
        let withdrawnVault <- strategyRef.withdraw(maxAmount: amount, ofToken: Type<@FlowToken.Vault>())

        // Deposit to the user's FlowToken vault
        let flowVault = user.storage.borrow<&FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")

        flowVault.deposit(from: <-withdrawnVault)
    }
}
