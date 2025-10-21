import "FlowLiquidStakingStrategy"
import "FlowToken"

/// Script to get the balance of a FlowLiquidStakingStrategy
access(all) fun main(account: Address): UFix64 {
    let authAccount = getAuthAccount<auth(Storage) &Account>(account)
    let strategy = authAccount.storage.borrow<&FlowLiquidStakingStrategy.Strategy>(from: /storage/FlowLiquidStakingStrategy)!
    return strategy.availableBalance(ofToken: Type<@FlowToken.Vault>())
}
