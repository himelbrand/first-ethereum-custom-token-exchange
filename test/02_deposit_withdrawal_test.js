const FixedSupplyToken = artifacts.require('./FixedSupplyToken.sol')
const Exchange = artifacts.require('./Exchange.sol')

contract('MyExchangeDepositAndWithdrawal', accounts => {
    let myTokenInstance, myExchangeInstance
    const owner = accounts[0]
    it('Deploy FixedSupplyToken', () => {
        FixedSupplyToken.deployed().then(instance => {
            myTokenInstance = instance
            assert(true)
        }) 
    })

    it('Deploy Exchange and add Token', () => {
        return Exchange.deployed().then(instance => {
            myExchangeInstance = instance
            return myExchangeInstance.addToken('FIXED', myTokenInstance.address).then(() => {
                return myExchangeInstance.hasToken('FIXED').then(flag => {
                    assert.equal(flag, true, 'Should of added FIXED symbol token')
                })
            })
        })
    })
    it('Aprove Exchange for deposits', () => {
        return myTokenInstance.approve(myExchangeInstance.address, 1000).then(() => {
            assert(true, 'Should of aproved Exchange to move 1000 tokens')
        })
    })
    it('Deposit FixedSupplyToken in exchange', () => {
        let initialBalance
        return myExchangeInstance.getBalance('FIXED').then(balance => {
            initialBalance = balance.toNumber()
            return myExchangeInstance.depositToken('FIXED', 1000).then(() => {
                return myExchangeInstance.getBalance('FIXED').then(balance => {
                    assert.equal(initialBalance + 1000, balance.toNumber(), 'Should of deposited 1000 tokens')
                })
            })
        })
    })
    it('Withdraw FixedSupplyToken from exchange', () => {
        let initialBalance
        return myExchangeInstance.getBalance('FIXED').then(balance => {
            initialBalance = balance.toNumber()
            return myExchangeInstance.withdrawToken('FIXED', 1000).then(() => {
                return myExchangeInstance.getBalance('FIXED').then(balance => {
                    assert.equal(initialBalance - 1000, balance.toNumber(), 'Should of withdrawed 1000 tokens')
                })
            })
        })
    })
    it('Deposit Ether in exchange', () => {
        let initialBalance
        return myExchangeInstance.getEthBalanceInWei().then(balance => {
            initialBalance = balance.toNumber()
            return myExchangeInstance.depositEther({ value: 1000 }).then(() => {
                return myExchangeInstance.getEthBalanceInWei().then(balance => {
                    assert.equal(initialBalance + 1000, balance.toNumber(), 'Should of deposited 1000 wei')
                })
            })
        })
    })
    it('Withdraw Ether from exchange', () => {
        let initialBalance
        return myExchangeInstance.getEthBalanceInWei().then(balance => {
            initialBalance = balance.toNumber()
            return myExchangeInstance.withdrawEther(1000).then(() => {
                return myExchangeInstance.getEthBalanceInWei().then(balance => {
                    assert.equal(initialBalance - 1000, balance.toNumber(), 'Should of withdrawed 1000 wei')
                })
            })
        })
    })
})




