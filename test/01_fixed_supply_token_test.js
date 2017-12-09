const FixedSupplyToken = artifacts.require('./FixedSupplyToken.sol')

contract('MyToken', accounts => {
    let myTokenInstance
    let _totalSupply
    it('first account should own all the tokens', () => {
        return FixedSupplyToken.deployed().then(instance => {
            myTokenInstance = instance
            return myTokenInstance.totalSupply.call()
        }).then(totalSupply => {
            _totalSupply = totalSupply
            return myTokenInstance.balanceOf(accounts[0])
        }).then(balance => {
            assert.equal(balance.toNumber(), _totalSupply.toNumber(), 'Total supply is owned by owner')
        })
    })
    it('second account has no tokens', () => {
        return myTokenInstance.balanceOf(accounts[1]).then(secondBalance => {
            assert.equal(secondBalance.toNumber(), 0, 'second account should have no tokens')
        })
    })
    it('correct transfer of tokens between accounts', () => {
        const account1 = accounts[0]
        const account2 = accounts[1]
        let firstBalance1, firstBalance2, secondBalance1, secondBalance2
        return myTokenInstance.balanceOf(account1).then(balance => {
            firstBalance1 = balance
            return myTokenInstance.balanceOf(account2).then(balance => {
                secondBalance1 = balance
                return myTokenInstance.transfer(account2, 1000, { from: account1 }).then(() => {
                    return myTokenInstance.balanceOf(account1).then(balance => {
                        firstBalance2 = balance
                        return myTokenInstance.balanceOf(account2).then(balance => {
                            secondBalance2 = balance
                            assert.equal(firstBalance1.toNumber() - 1000, firstBalance2.toNumber(), 'account1 should have 1000 tokens less')
                            assert.equal(secondBalance1.toNumber() + 1000, secondBalance2.toNumber(), 'account2 should have 1000 tokens more')
                        })
                    })
                })
            })
        })
    })
})
