import "FungibleToken"
import "FlowToken"
import "Burner"
import "DeFiActions"
import "TidalYield"
import "stFlowToken"
import "LiquidStaking"
import "FlowTransactionScheduler"

/// FlowLiquidStakingStrategy
///
/// A Flow Liquid Staking Strategy implementation.
/// This Strategy stakes Flow tokens and earns yield from staking rewards.
///
access(all) contract FlowLiquidStakingStrategy {

    /// FlowLiquidStakingStrategy resource implements the TidalYield.Strategy interface
    /// Incoming tokens are swapped to liquid staking tokens, and swapped back to
    /// the original tokens when withdrawn.
    access(all) resource Strategy : TidalYield.Strategy, DeFiActions.IdentifiableResource, FlowTransactionScheduler.TransactionHandler {
        /// An optional identifier allowing protocols to identify this strategy
        access(contract) var uniqueID: DeFiActions.UniqueIdentifier?

        /// The type of vault this strategy supports
        access(self) let supportedVaultType: Type

        /// Internal storage vault that holds deposited funds
        access(self) let storageVault: @stFlowToken.Vault

        /// An optional sink to deposit profit to
        access(self) let profitSink: {DeFiActions.Sink}?

        /// Any balance over this threshold will be deposited to the profit sink (in FLOW)
        access(self) var balanceThresholdInFlow: UFix64

        /// The scheduled transaction for the profit withdrawal
        access(self) var scheduledTransaction: @FlowTransactionScheduler.ScheduledTransaction?
        access(self) var schedulerCapability: Capability<auth(FlowTransactionScheduler.Execute) &Strategy>?
        access(self) var profitWithdrawalInterval: UFix64

        /// Initializes the FlowLiquidStakingStrategy
        /// You can optionally pass a profit sink to deposit any profits made from staking to
        init(uniqueID: DeFiActions.UniqueIdentifier, initialVault: @FlowToken.Vault, profitSink: {DeFiActions.Sink}?, profitWithdrawalInterval: UFix64?) {
            self.uniqueID = uniqueID
            self.profitSink = profitSink
            self.supportedVaultType = Type<@FlowToken.Vault>()
            self.balanceThresholdInFlow = initialVault.balance
            let stFlowVault <- FlowLiquidStakingStrategy.convertFlowToStFlow(flowVault: <- initialVault)
            self.storageVault <- stFlowVault
            self.scheduledTransaction <- nil
            self.schedulerCapability = nil
            self.profitWithdrawalInterval = profitWithdrawalInterval ?? 1.0 // 1 second
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
            self.balanceThresholdInFlow = self.balanceThresholdInFlow + amount
            let stFlowVault <- FlowLiquidStakingStrategy.convertFlowToStFlow(flowVault: <- depositVault)
            self.storageVault.deposit(from: <-stFlowVault)
        }

        /// Withdraws up to the specified amount from this Strategy
        access(FungibleToken.Withdraw) fun withdraw(maxAmount: UFix64, ofToken: Type): @{FungibleToken.Vault} {
            // TODO: add withdrawal of type stFlowToken.Vault
            pre {
                ofToken == self.supportedVaultType:
                    "Cannot withdraw vault of type \(ofToken.identifier) - only \(self.supportedVaultType.identifier) is supported"
            }
            let availableAmountInStFlow = self.storageVault.balance
            // Convert the max amount to stFlow amount
            let maxAmountInStFlow = LiquidStaking.calcStFlowFromFlow(flowAmount: maxAmount)
            let withdrawAmount = maxAmountInStFlow > availableAmountInStFlow ? availableAmountInStFlow : maxAmountInStFlow
            // Withdraw the stFlow tokens from the storage vault
            let stFlowVault <- self.storageVault.withdraw(amount: withdrawAmount) as! @stFlowToken.Vault
            // Unstake the stFlow tokens from the Liquid Staking contract
            let flowVault <- FlowLiquidStakingStrategy.convertStFlowToFlow(stFlowVault: <- stFlowVault)
            // Update the balance threshold
            self.balanceThresholdInFlow = self.balanceThresholdInFlow - flowVault.balance
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

        /// Sets the scheduler capability for this Strategy
        /// The user needs to call this method after creating the strategy and storing it in their account storage
        /// This will also schedule the next profit withdrawal
        access(FungibleToken.Withdraw) fun setSchedulerCapability(_ capability: Capability<auth(FlowTransactionScheduler.Execute) &Strategy>) {
            self.schedulerCapability = capability
            self.scheduleNextProfitWithdrawal()
        }

        /// Schedules the next profit withdrawal
        access(self) fun scheduleNextProfitWithdrawal() {
            if self.schedulerCapability == nil {
                return
            }
            let future = getCurrentBlock().timestamp + self.profitWithdrawalInterval
            let pr = FlowTransactionScheduler.Priority.Medium
            let est = FlowTransactionScheduler.estimate(
                data: nil,
                timestamp: future,
                priority: pr,
                executionEffort: 9999
            )
            assert(
                est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
                message: est.error ?? "estimation failed"
            )
            let fees <- self.withdraw(maxAmount: est.flowFee!, ofToken: Type<@FlowToken.Vault>())
            let scheduledTransaction <- FlowTransactionScheduler.schedule(
                handlerCap: self.schedulerCapability!,
                data: nil,
                timestamp: future,
                priority: pr,
                executionEffort: 9999,
                fees: <-fees as! @FlowToken.Vault
            )

            let currentTx <- self.scheduledTransaction <- scheduledTransaction
            destroy currentTx
        }

        /// Scheduled transaction execution logic
        /// Withdraws tokens above the threshold amount to the given user sink
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            if self.profitSink != nil && self.balanceThresholdInFlow > 0.0 {
                let currentBalance = self.availableBalance(ofToken: Type<@FlowToken.Vault>())
                if currentBalance > self.balanceThresholdInFlow {
                    let profitAmount = currentBalance - self.balanceThresholdInFlow
                    let profitVault <- self.withdraw(maxAmount: profitAmount, ofToken: Type<@FlowToken.Vault>())
                    self.profitSink!.depositCapacity(from: &profitVault as auth(FungibleToken.Withdraw) &{FungibleToken.Vault})
                    destroy profitVault
                }
                self.scheduleNextProfitWithdrawal()
            }
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
            pre {
                type == Type<@Strategy>():
                    "FlowLiquidStakingStrategyComposer can only create FlowLiquidStakingStrategy, not \(type.identifier)"
                withFunds.getType() == Type<@FlowToken.Vault>():
                    "FlowLiquidStakingStrategy can only be initialized with FlowToken.Vault, not \(withFunds.getType().identifier)"
            }

            let flowVault <- withFunds as! @FlowToken.Vault
            return <- create Strategy(uniqueID: uniqueID, initialVault: <-flowVault, profitSink: nil, profitWithdrawalInterval: nil)
        }
    }

    /// Creates and returns a new FlowLiquidStakingStrategyComposer
    access(all) fun createComposer(): @FlowLiquidStakingStrategyComposer {
        return <- create FlowLiquidStakingStrategyComposer()
    }

    /// Creates a new FlowLiquidStakingStrategy instance with the provided funds and profit sink
    /// Non-standard initialization parameteres are not supported by the standard TidalYield.StrategyComposer.createStrategy method
    access(all) fun createStrategyWithProfitSink(
        uniqueID: DeFiActions.UniqueIdentifier,
        withFunds: @FlowToken.Vault,
        profitSink: {DeFiActions.Sink},
        profitWithdrawalInterval: UFix64?
    ): @{TidalYield.Strategy} {
        return <- create Strategy(uniqueID: uniqueID, initialVault: <-withFunds, profitSink: profitSink, profitWithdrawalInterval: profitWithdrawalInterval)
    }

    /// Converts a FlowToken.Vault to a stFlowToken.Vault
    /// TODO: also check prices in stable/non-stable swap pools and use them to swap the Flow tokens to liquid staking tokens
    access(contract) fun convertFlowToStFlow(flowVault: @FlowToken.Vault): @stFlowToken.Vault {
        let stFlowVault <- LiquidStaking.stake(flowVault: <- flowVault)
        return <-stFlowVault
    }

    /// Converts a stFlowToken.Vault to a FlowToken.Vault
    /// TODO: also check prices in stable/non-stable swap pools and use them to swap the Flow tokens to liquid staking tokens
    access(contract) fun convertStFlowToFlow(stFlowVault: @stFlowToken.Vault): @FlowToken.Vault {
        let flowVault <- LiquidStaking.unstakeQuickly(stFlowVault: <- stFlowVault)
        return <-flowVault
    }

    init() {
        // Contract initialization - nothing required for this FlowLiquidStakingStrategy contract
    }
}
