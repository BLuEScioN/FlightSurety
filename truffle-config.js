const fs = require("fs");

// const infuraKey = "22bf701267374bd58d48dc882b501e23";
const infuraKey = fs
  .readFileSync(".secret-infura-key")
  .toString()
  .trim();
var HDWalletProvider = require("@truffle/hdwallet-provider");
const testMetaMaskMnemonic = fs
  .readFileSync(".secret-metamask-mnemonic")
  .toString()
  .trim();
const ganacheGuiMnemonic =
  "actor shadow tragic world note slender age save token fossil poet cable"; // ganche blockchain network
const ganacheCliMnemonic =
  "lumber warfare budget length hunt initial main crew silly flower perfect benefit"; // ganche blockchain network

module.exports = {
  networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(
          ganacheGuiMnemonic,
          "http://127.0.0.1:7545/",
          0,
          50
        );
      },
      // host: "127.0.0.1",
      // port: 7545,
      network_id: "*", //5777
      gas: 6721975,
    },
    development: {
      provider: function() {
        return new HDWalletProvider(
          ganacheGuiMnemonic,
          "http://127.0.0.1:7545/",
          0,
          50
        );
      },
      // host: "127.0.0.1",
      // port: 7545,
      network_id: "*", //5777
      gas: 6721975,
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(
          testMetaMaskMnemonic,
          `wss://rinkeby.infura.io/ws/v3/${infuraKey}`
        ),
      network_id: 4,
      gas: 5500000,
      gasPrice: 10000000000,
      // confirmations: 2,
      // timeoutBlocks: 200,
      // skipDryRun: true
    },
    compilers: {
      solc: {
        version: "^0.5.0",
      },
    },
  },
};
