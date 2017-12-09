const FixedSupplyToken = artifacts.require('./FixedSupplyToken.sol')
const Exchange = artifacts.require('./Exchange.sol')

contract('Simple Order Tests', accounts => {
    before(async () => {
        const ExchangeInstance = await Exchange.deployed()
        await ExchangeInstance.depositEther({ from: accounts[0], value: web3.toWei(3, "ether") })
        const instanceToken = await FixedSupplyToken.deployed()
        await ExchangeInstance.addToken("FIXED", instanceToken.address)
        await instanceToken.approve(ExchangeInstance.address, 2000)
        const txResponse = await ExchangeInstance.depositToken("FIXED", 2000)
        assert.equal(txResponse.logs[0].event, 'DepositForTokenReceived', 'The Log-Event should be DepositForTokenReceived')
    })

    it("should be possible to add a limit buy order", async () => {
        const myExchangeInstance = await Exchange.deployed()
        let orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        assert.equal(orderBook.length, 2, "BuyOrderBook should have 2 elements")
        assert.equal(orderBook[0].length, 0, "OrderBook should have 0 buy offers")
        const txResult = await myExchangeInstance.buyToken("FIXED", web3.toWei(1, "finney"), 5)
        assert.equal(txResult.logs.length, 1, "There should have been one Log Message emitted.")
        assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event should be LimitBuyOrderCreated")
        orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        assert.equal(orderBook[0].length, 1, "OrderBook should have 1 buy offers")
        assert.equal(orderBook[1].length, 1, "OrderBook should have 1 buy volume has one element")
    })

    it("should be possible to add three limit buy orders", async () => {
        const myExchangeInstance = await Exchange.deployed()
        let orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        const orderBookLengthBeforeBuy = orderBook[0].length
        let txResult = await myExchangeInstance.buyToken("FIXED", web3.toWei(2, "finney"), 5)
        assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event should be LimitBuyOrderCreated")
        txResult = await myExchangeInstance.buyToken("FIXED", web3.toWei(1.4, "finney"), 5)
        assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event should be LimitBuyOrderCreated")
        orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        assert.equal(orderBook[0].length, orderBookLengthBeforeBuy + 2, "OrderBook should have one more buy offers")
        assert.equal(orderBook[1].length, orderBookLengthBeforeBuy + 2, "OrderBook should have 2 buy volume elements")
    })


    it("should be possible to add two limit sell orders", async () => {
        const myExchangeInstance = await Exchange.deployed()
        let orderBook = await myExchangeInstance.getSellOrderBook.call("FIXED")
        let txResult = await myExchangeInstance.sellToken("FIXED", web3.toWei(3, "finney"), 5)
        assert.equal(txResult.logs.length, 1, "There should have been one Log Message emitted.")
        assert.equal(txResult.logs[0].event, "LimitSellOrderCreated", "The Log-Event should be LimitSellOrderCreated")
        txResult = await myExchangeInstance.sellToken("FIXED", web3.toWei(6, "finney"), 5)
        orderBook = await myExchangeInstance.getSellOrderBook.call("FIXED")
        assert.equal(orderBook[0].length, 2, "OrderBook should have 2 sell offers")
        assert.equal(orderBook[1].length, 2, "OrderBook should have 2 sell volume elements")
    })


    it("should be possible to create and cancel a buy order", async () => {
        const myExchangeInstance = await Exchange.deployed()
        let orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        const orderBookLengthBeforeBuy = orderBook[0].length
        let txResult = await myExchangeInstance.buyToken("FIXED", web3.toWei(2.2, "finney"), 5)
        assert.equal(txResult.logs.length, 1, "There should have been one Log Message emitted.")
        assert.equal(txResult.logs[0].event, "LimitBuyOrderCreated", "The Log-Event should be LimitBuyOrderCreated")
        const orderKey = txResult.logs[0].args._orderKey
        orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        const orderBookLengthAfterBuy = orderBook[0].length
        assert.equal(orderBookLengthAfterBuy, orderBookLengthBeforeBuy + 1, "OrderBook should have 1 buy offers more than before")
        txResult = await myExchangeInstance.cancelOrder("FIXED", false, web3.toWei(2, "finney"), orderKey)
        assert.equal(txResult.logs[0].event, "BuyOrderCanceled", "The Log-Event should be BuyOrderCanceled")
        orderBook = await myExchangeInstance.getBuyOrderBook.call("FIXED")
        const orderBookLengthAfterCancel = orderBook[0].length;
        assert.equal(orderBookLengthAfterCancel, orderBookLengthAfterBuy, "OrderBook should have 1 buy offers, its not cancelling it out completely, but setting the volume to zero")
        assert.equal(orderBook[1][orderBookLengthAfterCancel - 1], 0, "The available Volume should be zero")
    })

    it("should be possible to create and cancel a sell order", async () => {
        const myExchangeInstance = await Exchange.deployed()
        let orderBook = await myExchangeInstance.getSellOrderBook.call("FIXED")
        const orderBookLengthBeforeSell = orderBook[0].length
        let txResult = await myExchangeInstance.sellToken("FIXED", web3.toWei(2.5, "finney"), 5)
        assert.equal(txResult.logs.length, 1, "There should have been one Log Message emitted.")
        assert.equal(txResult.logs[0].event, "LimitSellOrderCreated", "The Log-Event should be LimitSellOrderCreated")
        const orderKey = txResult.logs[0].args._orderKey
        orderBook = await myExchangeInstance.getSellOrderBook.call("FIXED")
        const orderBookLengthAfterSell = orderBook[0].length
        assert.equal(orderBookLengthAfterSell, orderBookLengthBeforeSell + 1, "OrderBook should have 1 sell offers more than before")
        txResult = await myExchangeInstance.cancelOrder("FIXED", true, web3.toWei(2.5, "finney"), orderKey)
        assert.equal(txResult.logs[0].event, "SellOrderCanceled", "The Log-Event should be SellOrderCanceled")
        orderBook = await myExchangeInstance.getSellOrderBook.call("FIXED")
        const orderBookLengthAfterCancel = orderBook[0].length;
        assert.equal(orderBookLengthAfterCancel, orderBookLengthAfterSell, "OrderBook should have 1 sell offers, its not cancelling it out completely, but setting the volume to zero")
        assert.equal(orderBook[1][orderBookLengthAfterCancel - 1], 0, "The available Volume should be zero")
    })


});
