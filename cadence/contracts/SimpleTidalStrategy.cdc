import "FungibleToken"
import "FlowToken"
import "Burner"
import "DeFiActions"
import "TidalYield"

/// SimpleTidalStrategy
///
/// A simple placeholder Strategy implementation for testing purposes.
/// This Strategy simply holds tokens in an internal vault without any yield generation logic.
///
access(all) contract SimpleTidalStrategy {

    /// SimpleStrategy resource implements the TidalYield.Strategy interface
    /// This is a minimal implementation that stores funds in an internal vault
    access(all) resource SimpleStrategy : TidalYield.Strategy, DeFiActions.IdentifiableResource {
        /// An optional identifier allowing protocols to identify this strategy
        access(contract) var uniqueID: DeFiActions.UniqueIdentifier?

        /// The type of vault this strategy supports
        access(self) let supportedVaultType: Type

        /// Internal storage vault that holds deposited funds
        access(self) let storageVault: @{FungibleToken.Vault}

        init(uniqueID: DeFiActions.UniqueIdentifier, initialVault: @{FungibleToken.Vault}) {
            self.uniqueID = uniqueID
            self.supportedVaultType = initialVault.getType()
            self.storageVault <- initialVault
        }

        /// Returns the types of vaults supported by this Strategy
        access(all) view fun getSupportedCollateralTypes(): {Type: Bool} {
            return { self.supportedVaultType: true }
        }

        /// Returns the available balance for withdrawal of the specified token type
        access(all) fun availableBalance(ofToken: Type): UFix64 {
            if ofToken == self.supportedVaultType {
                return self.storageVault.balance
            }
            return 0.0
        }

        /// Deposits funds from the provided vault into this Strategy
        access(all) fun deposit(from: auth(FungibleToken.Withdraw) &{FungibleToken.Vault}) {
            pre {
                from.getType() == self.supportedVaultType:
                    "Cannot deposit vault of type \(from.getType().identifier) - only \(self.supportedVaultType.identifier) is supported"
            }
            let amount = from.balance
            let depositVault <- from.withdraw(amount: amount)
            self.storageVault.deposit(from: <-depositVault)
        }

        /// Withdraws up to the specified amount from this Strategy
        access(FungibleToken.Withdraw) fun withdraw(maxAmount: UFix64, ofToken: Type): @{FungibleToken.Vault} {
            pre {
                ofToken == self.supportedVaultType:
                    "Cannot withdraw vault of type \(ofToken.identifier) - only \(self.supportedVaultType.identifier) is supported"
            }
            let availableAmount = self.storageVault.balance
            let withdrawAmount = maxAmount > availableAmount ? availableAmount : maxAmount
            return <- self.storageVault.withdraw(amount: withdrawAmount)
        }

        /// Callback executed when this Strategy is burned
        access(contract) fun burnCallback() {
            // No-op for test strategy - cleanup handled in destroy()
        }

        /// Returns component information for this Strategy
        access(all) fun getComponentInfo(): DeFiActions.ComponentInfo {
            return DeFiActions.ComponentInfo(
                type: self.getType(),
                id: self.id(),
                innerComponents: []
            )
        }

        /// Returns a copy of the unique identifier
        access(contract) view fun copyID(): DeFiActions.UniqueIdentifier? {
            return self.uniqueID
        }

        /// Sets the unique identifier for this Strategy
        access(contract) fun setID(_ id: DeFiActions.UniqueIdentifier?) {
            self.uniqueID = id
        }
    }

    /// SimpleStrategyComposer creates SimpleStrategy instances
    access(all) resource SimpleStrategyComposer : TidalYield.StrategyComposer {

        /// Returns the Types of Strategies composed by this StrategyComposer
        access(all) view fun getComposedStrategyTypes(): {Type: Bool} {
            return { Type<@SimpleStrategy>(): true }
        }

        /// Returns the Vault types which can be used to initialize a SimpleStrategy
        access(all) view fun getSupportedInitializationVaults(forStrategy: Type): {Type: Bool} {
            if forStrategy == Type<@SimpleStrategy>() {
                return { Type<@FlowToken.Vault>(): true }
            }
            return {}
        }

        /// Returns the Vault types which can be deposited to a SimpleStrategy instance
        access(all) view fun getSupportedInstanceVaults(forStrategy: Type, initializedWith: Type): {Type: Bool} {
            if forStrategy == Type<@SimpleStrategy>() && initializedWith == Type<@FlowToken.Vault>() {
                return { Type<@FlowToken.Vault>(): true }
            }
            return {}
        }

        /// Creates a new SimpleStrategy instance with the provided funds
        access(all) fun createStrategy(
            _ type: Type,
            uniqueID: DeFiActions.UniqueIdentifier,
            withFunds: @{FungibleToken.Vault}
        ): @{TidalYield.Strategy} {
            pre {
                type == Type<@SimpleStrategy>():
                    "SimpleStrategyComposer can only create SimpleStrategy, not \(type.identifier)"
                withFunds.getType() == Type<@FlowToken.Vault>():
                    "SimpleStrategy can only be initialized with FlowToken.Vault, not \(withFunds.getType().identifier)"
            }

            return <- create SimpleStrategy(uniqueID: uniqueID, initialVault: <-withFunds)
        }
    }

    /// Creates and returns a new SimpleStrategyComposer
    access(all) fun createComposer(): @SimpleStrategyComposer {
        return <- create SimpleStrategyComposer()
    }

    init() {
        // Contract initialization - nothing required for this simple test contract
    }
}
