const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = ethers;

const IPFS_GATEWAY = 'https://gateway.pinata.cloud/ipfs/';

describe('NFT Worlds Server Router', () => {
  let contract;
  let tokenContract;
  let forwarderContract;
  let owner;
  let otherAddresses;

  beforeEach(async () => {
    const [ _owner, ..._otherAddresses ] = await ethers.getSigners();
    const WrldTokenFactory = await ethers.getContractFactory('WRLD_Token_Mock');
    const WRLDForwarderFactory = await ethers.getContractFactory('WRLD_Forwarder_Polygon');
    const NFTWorldsPlayersV1Factory = await ethers.getContractFactory('NFT_Worlds_Players_V1');

    owner = _owner;
    otherAddresses = _otherAddresses;

    forwarderContract = await WRLDForwarderFactory.deploy();
    tokenContract = await WrldTokenFactory.deploy(forwarderContract.address);
    contract = await NFTWorldsPlayersV1Factory.deploy(forwarderContract.address, IPFS_GATEWAY);
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
    expect(await contract.getPlayerPrimaryWallet(lcUsername)).to.equal(player.address);
    expect(await contract.assignedWalletPlayer(player.address)).to.equal(lcUsername);
  });

  it('Should set player secondary wallet', async () => {
    await contract.deployed();

    const player = otherAddresses[0];
    const username = 'iAmArkDev';
    const lcUsername = username.toLowerCase();

    await contract.connect(player).setPlayerSecondaryWallet(username);

    expect((await contract.getPlayerSecondaryWallets(username))[0]).to.equal(player.address);
    expect(await contract.assignedWalletPlayer(player.address)).to.equal(lcUsername);
  });

  it('Should set multiple player secondary wallets and return correct wallets after a removal', async () => {
    await contract.deployed();

    const wallet1 = otherAddresses[0];
    const wallet2 = otherAddresses[1];
    const wallet3 = otherAddresses[2];
    const username = 'iAmArkDev';

    await contract.connect(wallet1).setPlayerSecondaryWallet(username);
    await contract.connect(wallet2).setPlayerSecondaryWallet(username);
    await contract.connect(wallet3).setPlayerSecondaryWallet(username);

    const connectedSecondaryWallets = await contract.getPlayerSecondaryWallets(username);

    expect(connectedSecondaryWallets[0]).to.equal(wallet1.address);
    expect(connectedSecondaryWallets[1]).to.equal(wallet2.address);
    expect(connectedSecondaryWallets[2]).to.equal(wallet3.address);

    await contract.connect(wallet2).removePlayerSecondaryWallet(username);

    const updatedSecondaryWallets = await contract.getPlayerSecondaryWallets(username);

    if (updatedSecondaryWallets.includes(wallet2.address)) {
      throw new Error('Should now have wallet2 address');
    }
  });

  it('Should set player secondary wallet and remove it and allow it to be set on a different username', async () => {
    await contract.deployed();

    const wallet = otherAddresses[0];
    const username = 'iAmArkDev';
    const otherUsername = 'tester';
    const signature = generatePlayerWalletSignature(wallet.address, otherUsername.toLowerCase());

    await contract.connect(wallet).setPlayerSecondaryWallet(username);
    await expect(contract.connect(wallet).setPlayerSecondaryWallet(otherUsername)).to.be.reverted;
    await contract.connect(wallet).removePlayerSecondaryWallet(username);
    await contract.connect(wallet).setPlayerPrimaryWallet(otherUsername, signature);

    expect(await contract.getPlayerPrimaryWallet(otherUsername)).to.equal(wallet.address);
  });

  it('Should set player state data ipfs hash specific to the message sender address', async () => {
    await contract.deployed();

    const username = 'thiisa.Test';
    const lcUsername = username.toLowerCase();
    const ipfsHash = generateRandomIPFSHash();

    await contract.connect(owner).setPlayerStateData(username, ipfsHash);

    expect(await contract.getPlayerStateData(lcUsername, owner.address, false)).to.equal(`ipfs://${ipfsHash}`);
  });

  it('Should remove player secondary wallet', async () => {
    await contract.deployed();

    const player = otherAddresses[0];
    const username = 'iAmArkDev2';
    const lcUsername = username.toLowerCase();

    await contract.connect(player).setPlayerSecondaryWallet(lcUsername);
    expect((await contract.getPlayerSecondaryWallets(username))[0]).to.equal(player.address);

    await contract.connect(player).removePlayerSecondaryWallet(username);
    expect((await contract.getPlayerSecondaryWallets(username))[0]).to.equal(undefined);
  });

  it('Should remove player state data', async () => {
    await contract.deployed();

    const username = 'thiisa.Test';
    const lcUsername = username.toLowerCase();
    const ipfsHash = generateRandomIPFSHash();

    await contract.connect(owner).setPlayerStateData(username, ipfsHash);
    expect(await contract.getPlayerStateData(lcUsername, owner.address, false)).to.equal(`ipfs://${ipfsHash}`);

    await contract.connect(owner).removePlayerStateData(username);
    await expect(contract.getPlayerStateData(lcUsername, owner.address, false)).to.be.reverted;
  });

  it('Should set convenience gateway', async () => {
    await contract.deployed();

    const newGateway = 'https://test.nftworlds.com/ipfs/';

    await contract.connect(owner).setConvenienceGateway(newGateway);

    expect(await contract.convenienceGateway()).to.equal(newGateway);
  });

  it('Should set primary signer', async () => {
    await contract.deployed();

    const newSigner = otherAddresses[2];

    await contract.connect(owner).setPrimarySigner(newSigner.address);

    expect(await contract.primarySigner()).to.equal(newSigner.address);
  });

  it('Should set player primary wallet with gasless fee', async () => {
    await contract.deployed();
    await tokenContract.deployed();

    const signer = otherAddresses[0];
    const sender = otherAddresses[1];
    const username = 'iamarkdevadwada';
    const fee = getTokenDecimalAmount(2);
    const playerSignature = await generatePlayerWalletSignature(signer.address, username);

    await sendForwardedRequestWithFee({
      signer,
      sender,
      functionName: 'setPlayerPrimaryWalletGasless',
      fee,
      setArgs: [ username, playerSignature ],
    });

    expect(await contract.getPlayerPrimaryWallet(username)).to.equal(signer.address);
    expect(await contract.assignedWalletPlayer(signer.address)).to.equal(username);
    expect(await tokenContract.balanceOf(sender.address) * 1).to.equal(fee * 1);
  });

  it('Should set player secondary wallet with gasless fee', async () => {
    await contract.deployed();
    await tokenContract.deployed();

    const signer = otherAddresses[0];
    const sender = otherAddresses[1];
    const fee = getTokenDecimalAmount(2);
    const username = 'iamarkdev1231';

    await sendForwardedRequestWithFee({
      signer,
      sender,
      functionName: 'setPlayerSecondaryWalletGasless',
      fee,
      setArgs: [ username ],
    });

    expect((await contract.getPlayerSecondaryWallets(username))[0]).to.equal(signer.address);
    expect(await contract.assignedWalletPlayer(signer.address)).to.equal(username);
    expect(await tokenContract.balanceOf(sender.address) * 1).to.equal(fee * 1);
  });

  it('Should set multiple player secondary wallets and return correct wallets after a removal with gasless fees', async () => {
    await contract.deployed();

    const wallets = [ otherAddresses[0], otherAddresses[1], otherAddresses[2] ];
    const sender = otherAddresses[3];
    const fee = getTokenDecimalAmount(2);
    const username = 'iAmArkDev';

    for (let i = 0; i < wallets.length; i++) {
      await sendForwardedRequestWithFee({
        signer: wallets[i],
        sender,
        functionName: 'setPlayerSecondaryWalletGasless',
        fee,
        setArgs: [ username ],
      });
    }

    const connectedSecondaryWallets = await contract.getPlayerSecondaryWallets(username);

    expect(connectedSecondaryWallets[0]).to.equal(wallets[0].address);
    expect(connectedSecondaryWallets[1]).to.equal(wallets[1].address);
    expect(connectedSecondaryWallets[2]).to.equal(wallets[2].address);

    await contract.connect(wallets[1]).removePlayerSecondaryWallet(username);

    const updatedSecondaryWallets = await contract.getPlayerSecondaryWallets(username);

    if (updatedSecondaryWallets.includes(wallets[1].address)) {
      throw new Error('Should now have wallet2 address');
    }
  });

  it('Should set player state data ipfs hash specific to the message sender address', async () => {
    await contract.deployed();

    const signer = otherAddresses[0];
    const sender = otherAddresses[1];
    const fee = getTokenDecimalAmount(2);
    const username = 'thiisa.tryest';
    const ipfsHash = generateRandomIPFSHash();

    await sendForwardedRequestWithFee({
      signer,
      sender,
      functionName: 'setPlayerStateDataGasless',
      fee,
      setArgs: [ username, ipfsHash ],
    });

    expect(await contract.getPlayerStateData(username, signer.address, false)).to.equal(`ipfs://${ipfsHash}`);
  });

  it('Should remove player state data', async () => {
    await contract.deployed();

    const signer = otherAddresses[0];
    const sender = otherAddresses[1];
    const fee = getTokenDecimalAmount(2);
    const username = 'thiisa.Test';
    const ipfsHash = generateRandomIPFSHash();

    await sendForwardedRequestWithFee({
      signer,
      sender,
      functionName: 'setPlayerStateDataGasless',
      fee,
      setArgs: [ username, ipfsHash ],
    });
    expect(await contract.getPlayerStateData(username, signer.address, false)).to.equal(`ipfs://${ipfsHash}`);

    await sendForwardedRequestWithFee({
      signer,
      sender,
      functionName: 'removePlayerStateDataGasless',
      fee,
      setArgs: [ username ],
    });
    await expect(contract.getPlayerStateData(username, signer.address, false)).to.be.reverted;
  });

  /*
   * Helpers
   */

  async function sendForwardedRequestWithFee({ signer, sender, functionName, fee, setArgs }) {
    const chainId = 31337; // hardhat

    // mint some tokens for the signer to pay fees.
    await tokenContract.connect(signer).mint(signer.address, getTokenDecimalAmount(20));

    // Forwarder Sig Vars
    const domain = {
      chainId,
      name: 'WRLD_Forwarder_Polygon',
      verifyingContract: forwarderContract.address,
      version: '1.0.0',
    };

    const types = {
      ForwardRequest: [
        { name: 'from', type: 'address' },
        { name: 'to', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'gas', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'data', type: 'bytes' },
      ],
    };

    const forwarderNonce = await forwarderContract.getNonce(signer.address);

    // create fee request object and sig
    const feeGasEstimate = await tokenContract.connect(signer).estimateGas.transfer(sender.address, fee);
    const feeCallData = tokenContract.interface.encodeFunctionData('transfer', [
      sender.address,
      fee,
    ]);

    const feeForwardRequest = {
      from: signer.address,
      to: tokenContract.address,
      value: getTokenDecimalAmount(0),
      gas: feeGasEstimate,
      nonce: BigNumber.from(forwarderNonce * 1 + 1),
      data: feeCallData,
    };

    const feeSignature = await signer._signTypedData(
      domain,
      types,
      feeForwardRequest,
    );

    // create set player primary wallet request object and sig
    const setCallData = contract.interface.encodeFunctionData(functionName, [
      ...setArgs,
      feeForwardRequest,
      feeSignature,
    ]);

    const setForwardRequest = {
      from: signer.address,
      to: contract.address,
      value: getTokenDecimalAmount(0),
      gas: BigNumber.from(250000), // if we get a gas estimate, the nonces will mismatch..
      nonce: forwarderNonce,
      data: setCallData,
    };

    // Sign message
    const setSignature = await signer._signTypedData(
      domain,
      types,
      setForwardRequest,
    );

    // Execute forwarded transaction
    await forwarderContract.connect(sender).execute(setForwardRequest, setSignature);
  }

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

  function getTokenDecimalAmount(amount) {
    return BigNumber.from(BigInt(amount * 1e18));
  }
});
