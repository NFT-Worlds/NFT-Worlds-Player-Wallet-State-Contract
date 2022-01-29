const { expect } = require('chai');
const { ethers } = require('hardhat');

const IPFS_GATEWAY = 'https://gateway.pinata.cloud/ipfs/';

describe('NFT Worlds Server Router', () => {
  let contract;
  let owner;
  let otherAddresses;

  beforeEach(async () => {
    const [ _owner, ..._otherAddresses ] = await ethers.getSigners();
    const NFTWorldsPlayersFactory = await ethers.getContractFactory('NFT_Worlds_Players');

    owner = _owner;
    otherAddresses = _otherAddresses;
    contract = await NFTWorldsPlayersFactory.deploy(IPFS_GATEWAY);
  });

  it('Should deploy', async () => {
    await contract.deployed();
  });

  it('Should set player primary wallet', async () => {
    await contract.deployed();

    const player = otherAddresses[0];
    const username = '_ABCDEFGHIJKLmNOPQRSTUVWXYZ_.';
    const lcUsername = username.toLowerCase();
    const signature = generatePlayerWalletSignature(player.address, lcUsername);

    await contract.connect(player).setPlayerPrimaryWallet(username, signature);

    // Contract lowercases all usernames to maintain case insensitive usernames lookups.
    expect(await contract.playerPrimaryWallet(lcUsername)).to.equal(player.address);
    expect(await contract.assignedWalletPlayer(player.address)).to.equal(lcUsername);
  });

  it('Should set player secondary wallet', async () => {
    await contract.deployed();
  });

  it('Should set player state data ipfs hash specific to the message sender address', async () => {
    await contract.deployed();
  });

  it('Should remove player secondary wallet', async () => {
    await contract.deployed();
  });

  it('Should remove player state data', async () => {
    await contract.deployed();
  });

  it('Should set convenience gateway', async () => {
    await contract.deployed();
  });

  it('Should set signer', async () => {
    await contract.deployed();
  });

  it('Should be case insensitive reads of player primary wallet', async () => {
    await contract.deployed();
  });

  it('Should be case insensitive returns of assigner player to wallet', async () => {
    await contract.deployed();
  });

  it('Should be case insensitive reads of player secondary wallets', async () => {
    await contract.deployed();
  });

  it('Should be case insensitive reads of player state data', async () => {
    await contract.deployed();
  });

  /*
   * Helpers
   */

  async function generatePlayerWalletSignature(address, lcUsername) {
    const abiCoder = ethers.utils.defaultAbiCoder;

    const hash = ethers.utils.keccak256(abiCoder.encode(
      [ 'address', 'string' ],
      [ address, lcUsername ],
    ));

    return await owner.signMessage(ethers.utils.arrayify(hash));
  }

  function generateRandomIPFSHash() {
    // Declare all characters
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

    // Pick characers randomly
    let str = '';

    for (let i = 0; i < 46; i++) {
      str += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    return str;
  }
});
