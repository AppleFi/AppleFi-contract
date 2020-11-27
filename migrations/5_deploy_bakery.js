const ApplePieToken = artifacts.require('./ApplePieToken.sol');

module.exports =  function(deployer, network) {
    console.log("network", network ,'deploying ApplePieToken');
    deployer.deploy(ApplePieToken,"ApplePie","APLP")
};
