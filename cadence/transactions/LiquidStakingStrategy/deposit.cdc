import "FungibleToken"
import "FlowToken"
import "TidalYield"

/// Transaction to deposit additional funds to an existing Tide
transaction(amount: UFix64) {
    prepare(user: auth(Storage) &Account) {
        // Withdraw funds from the user's FlowToken vault
        let flowVault = user.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")
        let depositVault <- flowVault.withdraw(amount: amount)

        // Borrow from storage
        let strategyRef = user.storage.borrow<&{TidalYield.Strategy}>(from: /storage/LiquidStakingStrategy)!

        // Deposit to the strategy
        strategyRef.deposit(from: &depositVault as auth(FungibleToken.Withdraw) &{FungibleToken.Vault})

        assert(depositVault.balance == 0.0, message: "Deposit vault should be empty")
        destroy depositVault
    }
}
