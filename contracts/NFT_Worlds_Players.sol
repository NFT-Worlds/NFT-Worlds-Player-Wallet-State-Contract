// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFT_Worlds_Players is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ECDSA for bytes32;

  mapping(bytes32 => address) public playerPrimaryWallet;
  mapping(bytes32 => EnumerableSet.AddressSet) private playerSecondaryWallets;
  mapping(bytes32 => mapping(address => string)) private playerStateData;
  mapping(address => bool) private assignedWallets;
  string public convenienceGateway;
  address private signer;

  constructor(string memory _convenienceGateway) {
    convenienceGateway = _convenienceGateway;
  }

  function getPlayerSecondaryWallets(bytes32 _usernameHash) external view returns (address[] memory) {
    uint totalPlayerSecondaryWallets = playerSecondaryWallets[_usernameHash].length();
    address[] memory wallets = new address[](totalPlayerSecondaryWallets);

    for (uint i = 0; i < totalPlayerSecondaryWallets; i++) {
      wallets[i] = playerSecondaryWallets[_usernameHash].at(i);
    }

    return wallets;
  }

  function getPlayerStateData(bytes32 _usernameHash, address _setterAddress, bool includeGateway) external view returns(string memory) {
    string memory ipfsHash = playerStateData[_usernameHash][_setterAddress];

    require(bytes(ipfsHash).length > 0, "No player state data set");

    if (includeGateway) {
      return string(abi.encodePacked(convenienceGateway, ipfsHash));
    }

    return string(abi.encodePacked("ipfs://", ipfsHash));
  }

  function setPlayerPrimaryWallet(bytes32 _usernameHash, bytes calldata _signature) external {
    require(_verifySignerSignature(
      keccak256(abi.encode(msg.sender, _usernameHash)),
      _signature
    ), "Invalid Signature");

    require(!assignedWallets[msg.sender], "Wallet assigned");

    playerPrimaryWallet[_usernameHash] = msg.sender;
    assignedWallets[msg.sender] = true;
  }

  function setPlayerWallet(bytes32 _usernameHash) external {
    require(!assignedWallets[msg.sender], "Wallet assigned");

    playerSecondaryWallets[_usernameHash].add(msg.sender);
    assignedWallets[msg.sender] = true;
  }

  function setPlayerStateData(bytes32 _usernameHash, string calldata _ipfsHash) external {
    require(bytes(_ipfsHash).length == 46, "Invalid IPFS hash");

    playerStateData[_usernameHash][msg.sender] = _ipfsHash;
  }

  function removePlayerWallet(bytes32 _usernameHash) external {
    require(assignedWallets[msg.sender], "Wallet not assigned");

    playerSecondaryWallets[_usernameHash].remove(msg.sender);
    assignedWallets[msg.sender] = false;
  }

  function removePlayerStateData(bytes32 _usernameHash) external {
    playerStateData[_usernameHash][msg.sender] = "";
  }

  function setConvenienceGateway(string calldata _convenienceGateway) external onlyOwner {
    convenienceGateway = _convenienceGateway;
  }

  function setSigner(address _signer) external onlyOwner {
    signer = _signer;
  }

  /**
   * Security
   */

  function _verifySignerSignature(bytes32 hash, bytes calldata signature) internal view returns(bool) {
    return hash.toEthSignedMessageHash().recover(signature) == signer;
  }
}
