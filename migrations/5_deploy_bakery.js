const BakeryToken = artifacts.require('./BakeryToken.sol');

module.exports =  function(deployer, network) {
    console.log("network", network ,'deploying BakeryToken');
    deployer.deploy(BakeryToken,"ApplePie","APLP")
};
