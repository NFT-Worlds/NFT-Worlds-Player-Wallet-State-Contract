/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('hardhat-gas-reporter');
require('hardhat-abi-exporter');
require('hardhat-contract-sizer');
require('@nomiclabs/hardhat-etherscan');

module.exports = {
  solidity: {
    version: '0.8.2',
    settings: {
      optimizer: {
        enabled: true,
        runs: 20000,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    polygon: {
      url: process.env.POLYGON_MAINNET_URL,
    },
    polygonMumbai: {
      url: process.env.POLYGON_MUMBAI_URL,
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 50, // GWEI
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
    pretty: false,
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
  mocha: {
    timeout: 60 * 60 * 1000,
  },
};
