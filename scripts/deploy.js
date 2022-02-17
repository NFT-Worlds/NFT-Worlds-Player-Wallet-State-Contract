require('dotenv').config();

const { ethers } = require('hardhat');

const IS_PRODUCTION = true;

const FORWARDER_ADDRESS = '0x7fE3AEDfC76D7C6DD84b617081A9346DE81236DC';
const IPFS_GATEWAY = 'https://routing.nftworlds.com/ipfs/';

async function main() {
  const {
    POLYGON_MUMBAI_WEBSOCKET_URL,
    POLYGON_MUMBAI_ACCOUNT,
    POLYGON_MAINNET_WEBSOCKET_URL,
    POLYGON_MAINNET_ACCOUNT,
  } = process.env;

  const { Wallet } = ethers;
  const { WebSocketProvider } = ethers.providers;

  const polygonProvider = (IS_PRODUCTION)
    ? new WebSocketProvider(POLYGON_MAINNET_WEBSOCKET_URL)
    : new WebSocketProvider(POLYGON_MUMBAI_WEBSOCKET_URL);

  const polygonWallet = (IS_PRODUCTION)
    ? new Wallet(`0x${POLYGON_MAINNET_ACCOUNT}`, polygonProvider)
    : new Wallet(`0x${POLYGON_MUMBAI_ACCOUNT}`, polygonProvider);

  // increment so contract on eth & poly for token have matching addresses.
  const NFTWorldsPlayersV1_4Factory = await ethers.getContractFactory('NFT_Worlds_Players_V1_4', polygonWallet);
console.log(polygonWallet.address);
  // Deploy Polygon
  const polygonPlayersContract = await NFTWorldsPlayersV1_4Factory.deploy(
    FORWARDER_ADDRESS,
    IPFS_GATEWAY,
    { gasPrice: 100000000000, nonce: 0 },
  );

  console.log('Polygon WRLD Deploy TX Hash', polygonPlayersContract.deployTransaction.hash);
  await polygonPlayersContract.deployed();
  console.log('Polygon WRLD Address:', polygonPlayersContract.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit();
  });

// 0xD5d86FC8d5C0Ea1aC1Ac5Dfab6E529c9967a45E9 WRLD
// 0x7fE3AEDfC76D7C6DD84b617081A9346DE81236DC Forwarder
