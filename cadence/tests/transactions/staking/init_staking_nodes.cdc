import "DelegatorManager"
import "FlowIDTableStaking"
import "FungibleToken"
import "FlowToken"

/// Saves a copy of the admin-issued cap into the user's account
/// and publishes it under /public for easy script checks.
transaction() {

    prepare(
        delegatorManager: auth(Capabilities, Storage) &Account
    ) {
        let nodeID = "0x42"

        let flowTokenRef = delegatorManager.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow reference to FLOW Vault")

        let newDelegator <- FlowIDTableStaking.registerNewDelegator(nodeID: nodeID, tokensCommitted: <-flowTokenRef.withdraw(amount: 42.0))

        delegatorManager.storage.save(<-newDelegator, to: FlowIDTableStaking.DelegatorStoragePath)

        let delegatorCap = delegatorManager.capabilities.storage.issue<&{FlowIDTableStaking.NodeDelegatorPublic}>(FlowIDTableStaking.DelegatorStoragePath)
        delegatorManager.capabilities.publish(delegatorCap, at: /public/flowStakingDelegator)

        let admin = delegatorManager.storage.borrow<&DelegatorManager.Admin>(from: /storage/liquidStakingAdmin) ?? panic("Missing Admin")
        admin.initApprovedNodeIDList(nodeIDs: {
            nodeID: 1.0
        }, defaultNodeIDToStake: nodeID)
    }
}
