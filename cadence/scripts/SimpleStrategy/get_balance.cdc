import "SimpleTidalStrategy"
import "FlowToken"

/// Script to get the balance of a SimpleStrategy
access(all) fun main(account: Address): UFix64 {
    let authAccount = getAuthAccount<auth(Storage) &Account>(account)
    let strategy = authAccount.storage.borrow<&SimpleTidalStrategy.SimpleStrategy>(from: /storage/SimpleStrategy)!
    return strategy.availableBalance(ofToken: Type<@FlowToken.Vault>())
}
