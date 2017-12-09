var Exchange = artifacts.require("./Exchange.sol");
var FixedSupplyToken = artifacts.require("./FixedSupplyToken.sol")
module.exports = function(deployer) {
  deployer.deploy(FixedSupplyToken);
  deployer.deploy(Exchange);
};