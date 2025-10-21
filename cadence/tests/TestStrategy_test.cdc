import Test
import BlockchainHelpers

import "test_helpers.cdc"

access(all)
fun setup() {
    deployTidalContracts()

    // Deploy SimpleTidalStrategy
    var err = Test.deployContract(
        name: "SimpleTidalStrategy",
        path: "../../cadence/contracts/SimpleTidalStrategy.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun test_SimpleStrategyDeployment() {
    // Test that all contracts were deployed successfully
    log("All contracts deployed successfully")
}

access(all)
fun test_CreateTideWithSimpleStrategy() {
    // Create a user account with FLOW balance
    let user = Test.createAccount()

    let fundingAmount = 100.0
    let depositAmount = 50.0
    let withdrawAmount = 30.0

    var err = mintFlow(to: user, amount: fundingAmount + depositAmount)
    Test.expect(err, Test.beSucceeded())

    // Create a SimpleStrategy
    createSimpleStrategy(forUser: user, initialDeposit: fundingAmount)

    var balance = getSimpleStrategyBalance(user: user)
    Test.assertEqual(fundingAmount, balance)

    // Deposit funds to the strategy
    depositToSimpleStrategy(user: user, amount: depositAmount)

    balance = getSimpleStrategyBalance(user: user)
    Test.assertEqual(fundingAmount + depositAmount, balance)

    // Withdraw funds from the strategy
    let originalFlowBalance = getCurrentFlowBalance(user: user)
    withdrawFromSimpleStrategy(user: user, amount: withdrawAmount)
    let currentFlowBalance = getCurrentFlowBalance(user: user)
    Test.assertEqual(originalFlowBalance + withdrawAmount, currentFlowBalance)
}

access(all)
fun createSimpleStrategy(forUser: Test.TestAccount, initialDeposit: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/SimpleStrategy/create_strategy.cdc"),
        authorizers: [forUser.address],
        signers: [forUser],
        arguments: [initialDeposit]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun depositToSimpleStrategy(user: Test.TestAccount, amount: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/SimpleStrategy/deposit.cdc"),
        authorizers: [user.address],
        signers: [user],
        arguments: [amount]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun withdrawFromSimpleStrategy(user: Test.TestAccount, amount: UFix64) {
    let txn = Test.Transaction(
        code: Test.readFile("../../cadence/transactions/SimpleStrategy/withdraw.cdc"),
        authorizers: [user.address],
        signers: [user],
        arguments: [amount]
    )
    let txResult = Test.executeTransaction(txn)
    Test.expect(txResult, Test.beSucceeded())
}

access(all)
fun getSimpleStrategyBalance(user: Test.TestAccount): UFix64 {
    var script = Test.executeScript(
        Test.readFile("../../cadence/scripts/SimpleStrategy/get_balance.cdc"),
        [user.address]
    )
    Test.expect(script, Test.beSucceeded())
    var balance = script.returnValue as! UFix64
    return balance
}
