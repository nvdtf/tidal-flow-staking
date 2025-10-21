import "FungibleToken"
import "FlowToken"
import "FlowLiquidStakingStrategy"
import "DeFiActions"

/// Transaction to create a SimpleStrategy
transaction(amount: UFix64) {
    prepare(user: auth(Storage, Capabilities, CopyValue) &Account) {
        // Withdraw funds from the user's FlowToken vault
        let flowVault = user.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(
            from: /storage/flowTokenVault
        ) ?? panic("Could not borrow FlowToken vault")

        let fundingVault <- flowVault.withdraw(amount: amount)

        // Create a new SimpleStrategyComposer
        let composer <- FlowLiquidStakingStrategy.createComposer()

        // Create a new SimpleStrategy
        let strategy <- composer.createStrategy(
            Type<@FlowLiquidStakingStrategy.Strategy>(),
            uniqueID: DeFiActions.createUniqueIdentifier(),
            withFunds: <-fundingVault
        )

        destroy composer

        // Save the strategy to the user's storage
        user.storage.save(<-strategy, to: /storage/LiquidStakingStrategy)
    }
}
