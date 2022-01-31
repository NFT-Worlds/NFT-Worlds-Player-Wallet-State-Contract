// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract NFT_Worlds_Players is Ownable, ERC2771Context {
  using EnumerableSet for EnumerableSet.AddressSet;
  using ECDSA for bytes32;

  IERC20 immutable WRLD_ERC20;

  mapping(address => string) public assignedWalletPlayer;
  mapping(string => address) private playerPrimaryWallet;
  mapping(string => EnumerableSet.AddressSet) private playerSecondaryWallets;
  mapping(string => mapping(address => string)) private playerStateData;

  string public convenienceGateway;
  address public primarySigner;
  uint public gaslessFee = 1 ether; // $WRLD

  constructor(address _forwarder, address _wrld, string memory _convenienceGateway) ERC2771Context(_forwarder) {
    WRLD_ERC20 = IERC20(_wrld);
    convenienceGateway = _convenienceGateway;
    primarySigner = _msgSender();
  }

  /**
   * Player Reads
   */

  function getPlayerPrimaryWallet(string calldata _username) external view returns (address) {
    string memory lcUsername = _stringToLower(_username);

    return playerPrimaryWallet[lcUsername];
  }

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

  function setPlayerPrimaryWallet(string calldata _username, bytes calldata _signature) public {
    string memory lcUsername = _stringToLower(_username);

    require(_verifyPrimarySignerSignature(
      keccak256(abi.encode(_msgSender(), lcUsername)),
      _signature
    ), "Invalid Signature");

    require(bytes(assignedWalletPlayer[_msgSender()]).length == 0, "Wallet assigned");

    playerPrimaryWallet[lcUsername] = _msgSender();
    assignedWalletPlayer[_msgSender()] = lcUsername;
  }

  function setPlayerSecondaryWallet(string calldata _username) public {
    require(bytes(assignedWalletPlayer[_msgSender()]).length == 0, "Wallet assigned");

    string memory lcUsername = _stringToLower(_username);

    playerSecondaryWallets[lcUsername].add(_msgSender());
    assignedWalletPlayer[_msgSender()] = lcUsername;
  }

  function setPlayerStateData(string calldata _username, string calldata _ipfsHash) public {
    require(bytes(_ipfsHash).length == 46, "Invalid IPFS hash");

    string memory lcUsername = _stringToLower(_username);

    playerStateData[lcUsername][_msgSender()] = _ipfsHash;
  }

  function removePlayerSecondaryWallet(string calldata _username) public {
    require(bytes(assignedWalletPlayer[_msgSender()]).length > 0, "Wallet not assigned");

    string memory lcUsername = _stringToLower(_username);

    playerSecondaryWallets[lcUsername].remove(_msgSender());
    assignedWalletPlayer[_msgSender()] = "";
  }

  function removePlayerStateData(string calldata _username) public {
    string memory lcUsername = _stringToLower(_username);

    playerStateData[lcUsername][_msgSender()] = "";
  }

  /**
   * Gasless Player Writes
   */

  function setPlayerPrimaryWalletGasless(string calldata _username, bytes calldata _signature, address _feeRecipient) external {
    setPlayerPrimaryWallet(_username, _signature);
    WRLD_ERC20.transfer(_feeRecipient, gaslessFee);
  }

  function setPlayerSecondaryWalletGasless(string calldata _username, address _feeRecipient) external {
    setPlayerSecondaryWallet(_username);
    WRLD_ERC20.transfer(_feeRecipient, gaslessFee);
  }

  function setPlayerStateDataGasless(string calldata _username, string calldata _ipfsHash, address _feeRecipient) external {
    setPlayerStateData(_username, _ipfsHash);
    WRLD_ERC20.transfer(_feeRecipient, gaslessFee);
  }

  function removePlayerSecondaryWalletGasless(string calldata _username, address _feeRecipient) external {
    removePlayerSecondaryWallet(_username);
    WRLD_ERC20.transfer(_feeRecipient, gaslessFee);
  }

  function removePlayerStateDataGasless(string calldata _username, address _feeRecipient) external {
    removePlayerStateData(_username);
    WRLD_ERC20.transfer(_feeRecipient, gaslessFee);
  }

  /**
   * Owner only
   */

  function setConvenienceGateway(string calldata _convenienceGateway) external onlyOwner {
    convenienceGateway = _convenienceGateway;
  }

  function setPrimarySigner(address _primarySigner) external onlyOwner {
    primarySigner = _primarySigner;
  }

  function setGaslessFee(uint _fee) external onlyOwner {
    gaslessFee = _fee;
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
