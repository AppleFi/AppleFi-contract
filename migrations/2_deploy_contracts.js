const AppleFiToken = artifacts.require('./AppleFiToken.sol');
const MasterChef = artifacts.require('./MasterChef.sol');

module.exports = function(deployer) {
    deployer.deploy(AppleFiToken).then(() => {
        deployer.deploy(MasterChef, AppleFiToken.address, '0x6e0704331F38e439dF23D1b23A6B1C195c5E8493', '20891830');
    });
};
