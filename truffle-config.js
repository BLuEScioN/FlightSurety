var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "survey tissue zebra cotton report universe initial south inspire slide company refuse";

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:7545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999
    }
  },
  compilers: {
    solc: {
      version: "^0.5.0"
    }
  }
};