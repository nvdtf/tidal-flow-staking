access(all)
import Test

access(all)
fun deployTidalContracts() {
    // Deploy DeFiActions utility contracts
    var err = Test.deployContract(
        name: "DeFiActionsUtils",
        path: "../../lib/tidal-sc/lib/TidalProtocol/DeFiActions/cadence/contracts/utils/DeFiActionsUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "DeFiActionsMathUtils",
        path: "../../lib/tidal-sc/lib/TidalProtocol/DeFiActions/cadence/contracts/utils/DeFiActionsMathUtils.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy DeFiActions interface
    err = Test.deployContract(
        name: "DeFiActions",
        path: "../../lib/tidal-sc/lib/TidalProtocol/DeFiActions/cadence/contracts/interfaces/DeFiActions.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy TidalYield contracts
    err = Test.deployContract(
        name: "TidalYieldClosedBeta",
        path: "../../lib/tidal-sc/cadence/contracts/TidalYieldClosedBeta.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    err = Test.deployContract(
        name: "TidalYield",
        path: "../../lib/tidal-sc/cadence/contracts/TidalYield.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all)
fun getCurrentFlowBalance(user: Test.TestAccount): UFix64 {
    var script = Test.executeScript(
        Test.readFile("../../cadence/scripts/get_balance.cdc"),
        [user.address, /public/flowTokenBalance]
    )
    Test.expect(script, Test.beSucceeded())
    var balance = script.returnValue as! UFix64
    return balance
}