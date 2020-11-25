const HDWalletProvider = require("truffle-hdwallet-provider");

module.exports = {
  // Uncommenting the defaults below
  // provides for an easier quick-start with Ganache.
  // You can also follow this format for other networks;
  // see <http://truffleframework.com/docs/advanced/configuration>
  // for more details on how to specify configuration options!
  //
  networks: {
   kovan: {
     provider: function() {
       // private key: 0x92c365c2505649e0cb4e439f5572de6a549793154faddb00f309aaeff4990416
       // public key: 0x039f6737bd8c351d0a6849c2176b0c254f0ebb8dfe80969333eb5b737efd2a16e9	
       // address: 0x6e0704331F38e439dF23D1b23A6B1C195c5E8493
      return new HDWalletProvider('0x92c365c2505649e0cb4e439f5572de6a549793154faddb00f309aaeff4990416', 'https://kovan.infura.io/v3/997777f7800b410f82857d33b12aa7bb');
     },
     network_id: "42"
   },
  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1500
        }
      },
    }
  }
};
