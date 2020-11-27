const MasterBaker = artifacts.require('./MasterBaker.sol');
const ApplePieToken = artifacts.require('./ApplePieToken.sol');

module.exports =  function(deployer, network) {
    console.log("network", network , 'ApplePieToken:',ApplePieToken.address);
    console.log('ApplePieToken.address', ApplePieToken.address);
    deployer.deploy(MasterBaker,   ApplePieToken.address, '0x11CF52F333D55649f5c9C24B89a63116bDFdb36e', '0x5e9C6105a861C68349fA984D8c6c3e4363bCCAAC' );
};
