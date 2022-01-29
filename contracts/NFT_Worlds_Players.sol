// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract NFT_Worlds_Players is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ECDSA for bytes32;

  mapping(string => address) public playerPrimaryWallet;
  mapping(address => string) public assignedWalletPlayer;
  mapping(string => EnumerableSet.AddressSet) private playerSecondaryWallets;
  mapping(string => mapping(address => string)) private playerStateData;

  string public convenienceGateway;
  address private signer;

  constructor(string memory _convenienceGateway) {
    convenienceGateway = _convenienceGateway;
  }

  /**
   * Player Reads
   */

  function getPlayerSecondaryWallets(string calldata _username) external view returns (address[] memory) {
    string memory lcUsername = _stringToLower(_username);

    uint totalPlayerSecondaryWallets = playerSecondaryWallets[lcUsername].length();
    address[] memory wallets = new address[](totalPlayerSecondaryWallets);

    for (uint i = 0; i < totalPlayerSecondaryWallets; i++) {
      wallets[i] = playerSecondaryWallets[lcUsername].at(i);
    }

    return wallets;
  }

  function getPlayerStateData(string calldata _username, address _setterAddress, bool includeGateway) external view returns(string memory) {
    string memory lcUsername = _stringToLower(_username);
    string memory ipfsHash = playerStateData[lcUsername][_setterAddress];

    require(bytes(ipfsHash).length > 0, "No player state data set");

    if (includeGateway) {
      return string(abi.encodePacked(convenienceGateway, ipfsHash));
    }

    return string(abi.encodePacked("ipfs://", ipfsHash));
  }

  /**
   * Player Writes
   */

  function setPlayerPrimaryWallet(string calldata _username, bytes calldata _signature) external {
    string memory lcUsername = _stringToLower(_username);

    require(_verifySignerSignature(
      keccak256(abi.encode(msg.sender, lcUsername)),
      _signature
    ), "Invalid Signature");

    require(bytes(assignedWalletPlayer[msg.sender]).length == 0, "Wallet assigned");

    playerPrimaryWallet[lcUsername] = msg.sender;
    assignedWalletPlayer[msg.sender] = lcUsername;
  }

  function setPlayerSecondaryWallet(string calldata _username) external {
    require(bytes(assignedWalletPlayer[msg.sender]).length > 0, "Wallet assigned");

    string memory lcUsername = _stringToLower(_username);

    playerSecondaryWallets[lcUsername].add(msg.sender);
    assignedWalletPlayer[msg.sender] = lcUsername;
  }

  function setPlayerStateData(string calldata _username, string calldata _ipfsHash) external {
    require(bytes(_ipfsHash).length == 46, "Invalid IPFS hash");

    string memory lcUsername = _stringToLower(_username);

    playerStateData[lcUsername][msg.sender] = _ipfsHash;
  }

  function removePlayerWallet(string calldata _username) external {
    require(bytes(assignedWalletPlayer[msg.sender]).length > 0, "Wallet not assigned");

    string memory lcUsername = _stringToLower(_username);

    playerSecondaryWallets[lcUsername].remove(msg.sender);
    assignedWalletPlayer[msg.sender] = "";
  }

  function removePlayerStateData(string calldata _username) external {
    string memory lcUsername = _stringToLower(_username);

    playerStateData[lcUsername][msg.sender] = "";
  }

  /**
   * Owner only
   */

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

  /**
   * Utils
   */

  function _stringToLower(string memory _base) internal pure returns (string memory) {
    bytes memory _baseBytes = bytes(_base);

    for (uint i = 0; i < _baseBytes.length; i++) {
      _baseBytes[i] = (_baseBytes[i] >= 0x41 && _baseBytes[i] <= 0x5A)
        ? bytes1(uint8(_baseBytes[i]) + 32)
        : _baseBytes[i];
    }

    return string(_baseBytes);
  }
}
