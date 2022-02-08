// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct ForwardRequest {
  address from;
  address to;
  uint256 value;
  uint256 gas;
  uint256 nonce;
  bytes data;
}

interface IForwarder {
  function execute(ForwardRequest calldata req, bytes calldata signature) external payable returns (bool, bytes memory);
}

contract NFT_Worlds_Players_V1_1 is Ownable, ERC2771Context, ReentrancyGuard {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ECDSA for bytes32;

  IForwarder immutable feeForwarder;

  mapping(address => string) public assignedWalletUUID;
  mapping(string => address) private playerPrimaryWallet;
  mapping(string => EnumerableSet.AddressSet) private playerSecondaryWallets;
  mapping(string => mapping(address => string)) private playerStateData;

  string public convenienceGateway;
  address private primarySigner;

  constructor(address _forwarder, string memory _convenienceGateway) ERC2771Context(_forwarder) {
    feeForwarder = IForwarder(_forwarder);
    convenienceGateway = _convenienceGateway;
    primarySigner = _msgSender();
  }

  /**
   * Player Reads
   */

  function getPlayerPrimaryWallet(string calldata _playerUUID) external view returns (address) {
    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    return playerPrimaryWallet[lcPlayerUUID];
  }

  function getPlayerSecondaryWallets(string calldata _playerUUID) external view returns (address[] memory) {
    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    uint totalPlayerSecondaryWallets = playerSecondaryWallets[lcPlayerUUID].length();
    address[] memory wallets = new address[](totalPlayerSecondaryWallets);

    for (uint i = 0; i < totalPlayerSecondaryWallets; i++) {
      wallets[i] = playerSecondaryWallets[lcPlayerUUID].at(i);
    }

    return wallets;
  }

  function getPlayerStateData(string calldata _playerUUID, address _setterAddress, bool includeGateway) external view returns(string memory) {
    string memory lcPlayerUUID = _stringToLower(_playerUUID);
    string memory ipfsHash = playerStateData[lcPlayerUUID][_setterAddress];

    require(bytes(ipfsHash).length > 0, "No player state data set");

    if (includeGateway) {
      return string(abi.encodePacked(convenienceGateway, ipfsHash));
    }

    return string(abi.encodePacked("ipfs://", ipfsHash));
  }

  /**
   * Player Writes
   */

  function setPlayerPrimaryWallet(string calldata _playerUUID, bytes calldata _signature) public {
    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    require(_verifyPrimarySignerSignature(
      keccak256(abi.encode(_msgSender(), lcPlayerUUID)),
      _signature
    ), "Invalid Signature");

    require(bytes(assignedWalletUUID[_msgSender()]).length == 0, "Wallet assigned");

    playerPrimaryWallet[lcPlayerUUID] = _msgSender();
    assignedWalletUUID[_msgSender()] = lcPlayerUUID;
  }

  function setPlayerSecondaryWallet(string calldata _playerUUID) public {
    require(bytes(assignedWalletUUID[_msgSender()]).length == 0, "Wallet assigned");

    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    playerSecondaryWallets[lcPlayerUUID].add(_msgSender());
    assignedWalletUUID[_msgSender()] = lcPlayerUUID;
  }

  function setPlayerStateData(string calldata _playerUUID, string calldata _ipfsHash) public {
    require(bytes(_ipfsHash).length == 46, "Invalid IPFS hash");

    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    playerStateData[lcPlayerUUID][_msgSender()] = _ipfsHash;
  }

  function removePlayerSecondaryWallet(string calldata _playerUUID) public {
    require(bytes(assignedWalletUUID[_msgSender()]).length > 0, "Wallet not assigned");

    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    playerSecondaryWallets[lcPlayerUUID].remove(_msgSender());
    assignedWalletUUID[_msgSender()] = "";
  }

  function removePlayerStateData(string calldata _playerUUID) public {
    string memory lcPlayerUUID = _stringToLower(_playerUUID);

    playerStateData[lcPlayerUUID][_msgSender()] = "";
  }

  /**
   * Gasless Player Writes
   */

  function setPlayerPrimaryWalletGasless(
    string calldata _playerUUID,
    bytes calldata _signature,
    ForwardRequest calldata _feeForwardRequest,
    bytes calldata _feeSignature
  ) external nonReentrant {
    setPlayerPrimaryWallet(_playerUUID, _signature);
    feeForwarder.execute(_feeForwardRequest, _feeSignature);
  }

  function setPlayerSecondaryWalletGasless(
    string calldata _playerUUID,
    ForwardRequest calldata _feeForwardRequest,
    bytes calldata _feeSignature
  ) external nonReentrant {
    setPlayerSecondaryWallet(_playerUUID);
    feeForwarder.execute(_feeForwardRequest, _feeSignature);
  }

  function setPlayerStateDataGasless(
    string calldata _playerUUID,
    string calldata _ipfsHash,
    ForwardRequest calldata _feeForwardRequest,
    bytes calldata _feeSignature
  ) external nonReentrant {
    setPlayerStateData(_playerUUID, _ipfsHash);
    feeForwarder.execute(_feeForwardRequest, _feeSignature);
  }

  function removePlayerSecondaryWalletGasless(
    string calldata _playerUUID,
    ForwardRequest calldata _feeForwardRequest,
    bytes calldata _feeSignature
  ) external nonReentrant {
    removePlayerSecondaryWallet(_playerUUID);
    feeForwarder.execute(_feeForwardRequest, _feeSignature);
  }

  function removePlayerStateDataGasless(
    string calldata _playerUUID,
    ForwardRequest calldata _feeForwardRequest,
    bytes calldata _feeSignature
  ) external nonReentrant {
    removePlayerStateData(_playerUUID);
    feeForwarder.execute(_feeForwardRequest, _feeSignature);
  }

  /**
   * Owner only
   */

  function setConvenienceGateway(string calldata _convenienceGateway) external onlyOwner {
    require(bytes(_convenienceGateway).length > 0, "No gateway");
    convenienceGateway = _convenienceGateway;
  }

  function setPrimarySigner(address _primarySigner) external onlyOwner {
    require(_primarySigner != address(0), "Zero address");
    primarySigner = _primarySigner;
  }

  /**
   * Security
   */

  function _verifyPrimarySignerSignature(bytes32 hash, bytes calldata signature) internal view returns(bool) {
    return hash.toEthSignedMessageHash().recover(signature) == primarySigner;
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

  /**
   * Overrides
   */

  function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
    return super._msgSender();
  }

  function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
    return super._msgData();
  }
}
