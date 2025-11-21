import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all)
fun setup() {
    deployTidalContracts()

    // Deploy stFlowToken
    var err = Test.deployContract(
        name: "stFlowToken",
        path: "../../imports/d6f80565193ad727/stFlowToken.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy LiquidStaking
    err = Test.deployContract(
        name: "LiquidStakingConfig",
        path: "../../imports/d6f80565193ad727/LiquidStakingConfig.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "LiquidStakingError",
        path: "../../imports/d6f80565193ad727/LiquidStakingError.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "DelegatorManager",
        path: "../../imports/d6f80565193ad727/DelegatorManager.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "LiquidStaking",
        path: "../../imports/d6f80565193ad727/LiquidStaking.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy FlowLiquidStakingStrategy
    err = Test.deployContract(
        name: "FlowLiquidStakingStrategy",
        path: "../../cadence/contracts/FlowLiquidStakingStrategy.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Setup liquid staking contract parameters
    setupLiquidStaking()
}

access(all)
fun test_LiquidStakingStrategyDeployment() {
    // Test that all contracts were deployed successfully
    log("All contracts deployed successfully")
}

access(all)
fun test_CreateTideWithLiquidStakingStrategy() {
    // Create a user account with FLOW balance
    let user = Test.createAccount()

    let fundingAmount = 100.0
    let depositAmount = 50.0
    let withdrawAmount = 30.0

    var err = mintFlow(to: user, amount: fundingAmount + depositAmount)
    Test.expect(err, Test.beSucceeded())

    // Create a LiquidStakingStrategy
    createLiquidStakingStrategy(forUser: user, initialDeposit: fundingAmount)

    var balance = getLiquidStakingStrategyBalance(user: user)
    Test.assert(balance >= 0.0, message: "Balance should be greater than or equal to 0.0")

    // Deposit funds to the strategy
    depositToLiquidStakingStrategy(user: user, amount: depositAmount)

    var balanceAfterDeposit = getLiquidStakingStrategyBalance(user: user)
    Test.assert(balanceAfterDeposit > balance, message: "Balance should be greater than the previous balance")

    // Withdraw funds from the strategy
    let originalFlowBalance = getCurrentFlowBalance(user: user)
    withdrawFromLiquidStakingStrategy(user: user, amount: withdrawAmount)
    let currentFlowBalance = getCurrentFlowBalance(user: user)
    Test.assert(currentFlowBalance > originalFlowBalance, message: "Current flow balance should be greater than the original flow balance after withdrawal")
}

access(all)
fun createLiquidStakingStrategy(forUser: Test.TestAccount, initialDeposit: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/LiquidStakingStrategy/create_strategy.cdc"),
        authorizers: [forUser.address],
        signers: [forUser],
        arguments: [initialDeposit]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun depositToLiquidStakingStrategy(user: Test.TestAccount, amount: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/LiquidStakingStrategy/deposit.cdc"),
        authorizers: [user.address],
        signers: [user],
        arguments: [amount]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun withdrawFromLiquidStakingStrategy(user: Test.TestAccount, amount: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/LiquidStakingStrategy/withdraw.cdc"),
        authorizers: [user.address],
        signers: [user],
        arguments: [amount]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun getLiquidStakingStrategyBalance(user: Test.TestAccount): UFix64 {
    var script = Test.executeScript(
        Test.readFile("../../cadence/scripts/LiquidStakingStrategy/get_balance.cdc"),
        [user.address]
    )
    Test.expect(script, Test.beSucceeded())
    var balance = script.returnValue as! UFix64
    return balance
}