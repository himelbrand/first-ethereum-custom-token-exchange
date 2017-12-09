const FixedSupplyToken = artifacts.require('./FixedSupplyToken.sol')
const Exchange = artifacts.require('./Exchange.sol')

contract('MyExchangeDepositAndWithdrawal', accounts => {
    let myTokenInstance = null, myExchangeInstance = null
    it('Deploy FixedSupplyToken and Exchange', async () => {
        myTokenInstance = await FixedSupplyToken.deployed()
        myExchangeInstance = await Exchange.deployed()
        assert(myExchangeInstance!==null && myTokenInstance!==null,'Instances sould have been deployed')
    })
    it('Aprove Exchange for deposits',async () => {
        await myTokenInstance.approve(myExchangeInstance.address, 1000)
        assert(true, 'Should of aproved Exchange to move 1000 tokens')
    })
    it('Add token to Exchange event should fire',async () => {
        const tx = await myExchangeInstance.addToken('HIMELBRAND', myTokenInstance.address)
        assert.equal(tx.logs[0].event,'TokenAddedToSystem','TokenAddedToSystem should of fired')
    })
    it('Deposit token to Exchange event should fire',async () => {
        const tx = await myExchangeInstance.depositToken('HIMELBRAND', 1000)
        assert.equal(tx.logs[0].event,'DepositForTokenReceived','DepositForTokenReceived should of fired')
    })
    it('Withdraw token from Exchange event should fire',async () => {
        const tx = await myExchangeInstance.withdrawToken('HIMELBRAND', 1000)
        assert.equal(tx.logs[0].event,'WithdrawalToken','WithdrawalToken should of fired')
    })
    it('Deposit Ether to Exchange event should fire',async () => {
        const tx = await myExchangeInstance.depositEther({ value: 1000 })
        assert.equal(tx.logs[0].event,'DepositForEthReceived','DepositForEthReceived should of fired')
    })
    it('Withdraw Ether from Exchange event should fire',async () => {
        const tx = await myExchangeInstance.withdrawEther(1000)
        assert.equal(tx.logs[0].event,'WithdrawalEth','WithdrawalEth should of fired')
    })
})