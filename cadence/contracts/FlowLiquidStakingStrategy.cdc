import "FungibleToken"
import "FlowToken"
import "Burner"
import "DeFiActions"
import "TidalYield"
import "stFlowToken"
import "LiquidStaking"

/// FlowLiquidStakingStrategy
///
/// A Flow Liquid Staking Strategy implementation.
/// This Strategy stakes Flow tokens and earns yield from staking rewards.
///
access(all) contract FlowLiquidStakingStrategy {

    /// FlowLiquidStakingStrategy resource implements the TidalYield.Strategy interface
    /// Incoming tokens are swapped to liquid staking tokens, and swapped back to
    /// the original tokens when withdrawn.
    access(all) resource Strategy : TidalYield.Strategy, DeFiActions.IdentifiableResource {
        /// An optional identifier allowing protocols to identify this strategy
        access(contract) var uniqueID: DeFiActions.UniqueIdentifier?

        /// The type of vault this strategy supports
        access(self) let supportedVaultType: Type

        /// Internal storage vault that holds deposited funds
        access(self) let storageVault: @stFlowToken.Vault

        init(uniqueID: DeFiActions.UniqueIdentifier, initialVault: @{FungibleToken.Vault}) {
            self.uniqueID = uniqueID
            self.supportedVaultType = Type<@FlowToken.Vault>()
            if initialVault.getType() == Type<@FlowToken.Vault>() {
                let flowVault <- initialVault as! @FlowToken.Vault
                let stFlowVault <- LiquidStaking.stake(flowVault: <- flowVault)
                self.storageVault <- stFlowVault
            } else {
                panic("Invalid initial vault type")
            }
        }

        /// Returns the types of vaults supported by this Strategy
        access(all) view fun getSupportedCollateralTypes(): {Type: Bool} {
            return { self.supportedVaultType: true }
        }

        /// Returns the available balance for withdrawal of the specified token type
        access(all) fun availableBalance(ofToken: Type): UFix64 {
            if ofToken == self.supportedVaultType {
                return LiquidStaking.calcFlowFromStFlow(stFlowAmount: self.storageVault.balance)
            }
            return 0.0
        }

        /// Deposits funds from the provided vault into this Strategy
        access(all) fun deposit(from: auth(FungibleToken.Withdraw) &{FungibleToken.Vault}) {
            // TODO: add deposit of type stFlowToken.Vault
            pre {
                from.getType() == self.supportedVaultType:
                    "Cannot deposit vault of type \(from.getType().identifier) - only \(self.supportedVaultType.identifier) is supported"
            }
            let amount = from.balance
            let depositVault <- from.withdraw(amount: amount) as! @FlowToken.Vault
            // TODO: check prices in stable/non-stable swap pools and use them to swap the Flow tokens to liquid staking tokens
            let liquidVault <- LiquidStaking.stake(flowVault: <- depositVault)
            self.storageVault.deposit(from: <-liquidVault)
        }

        /// Withdraws up to the specified amount from this Strategy
        access(FungibleToken.Withdraw) fun withdraw(maxAmount: UFix64, ofToken: Type): @{FungibleToken.Vault} {
            // TODO: add withdrawal of type stFlowToken.Vault
            pre {
                ofToken == self.supportedVaultType:
                    "Cannot withdraw vault of type \(ofToken.identifier) - only \(self.supportedVaultType.identifier) is supported"
            }
            //let availableAmount = self.availableBalance(ofToken: Type<@FlowToken.Vault>())
            let availableAmount = self.storageVault.balance
            // Convert the max amount to stFlow amount
            let maxAmountInStFlow = LiquidStaking.calcStFlowFromFlow(flowAmount: maxAmount)
            let withdrawAmount = maxAmountInStFlow > availableAmount ? availableAmount : maxAmountInStFlow
            // Withdraw the stFlow tokens from the storage vault
            let stFlowVault <- self.storageVault.withdraw(amount: withdrawAmount) as! @stFlowToken.Vault
            // Unstake the stFlow tokens from the Liquid Staking contract
            // TODO: check prices in stable/non-stable swap pools and use them to swap the stFlow tokens to flow tokens
            let flowVault <- LiquidStaking.unstakeQuickly(stFlowVault: <- stFlowVault)
            // Return the flow tokens to the caller
            return <-flowVault
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

    /// FlowLiquidStakingStrategyComposer creates FlowLiquidStakingStrategy instances
    access(all) resource FlowLiquidStakingStrategyComposer : TidalYield.StrategyComposer {

        /// Returns the Types of Strategies composed by this StrategyComposer
        access(all) view fun getComposedStrategyTypes(): {Type: Bool} {
            return { Type<@Strategy>(): true }
        }

        /// Returns the Vault types which can be used to initialize a FlowLiquidStakingStrategy
        access(all) view fun getSupportedInitializationVaults(forStrategy: Type): {Type: Bool} {
            return { Type<@FlowToken.Vault>(): true }
        }

        /// Returns the Vault types which can be deposited to a FlowLiquidStakingStrategy instance
        access(all) view fun getSupportedInstanceVaults(forStrategy: Type, initializedWith: Type): {Type: Bool} {
            if forStrategy == Type<@Strategy>() && initializedWith == Type<@FlowToken.Vault>() {
                return { Type<@FlowToken.Vault>(): true }
            }
            return {}
        }

        /// Creates a new FlowLiquidStakingStrategy instance with the provided funds
        access(all) fun createStrategy(
            _ type: Type,
            uniqueID: DeFiActions.UniqueIdentifier,
            withFunds: @{FungibleToken.Vault}
        ): @{TidalYield.Strategy} {
            // TODO: initialize with type stFlowToken.Vault
            pre {
                type == Type<@Strategy>():
                    "FlowLiquidStakingStrategyComposer can only create FlowLiquidStakingStrategy, not \(type.identifier)"
                withFunds.getType() == Type<@FlowToken.Vault>():
                    "FlowLiquidStakingStrategy can only be initialized with FlowToken.Vault, not \(withFunds.getType().identifier)"
            }

            return <- create Strategy(uniqueID: uniqueID, initialVault: <-withFunds)
        }
    }

    /// Creates and returns a new FlowLiquidStakingStrategyComposer
    access(all) fun createComposer(): @FlowLiquidStakingStrategyComposer {
        return <- create FlowLiquidStakingStrategyComposer()
    }

    init() {
        // Contract initialization - nothing required for this FlowLiquidStakingStrategy contract
    }
}
