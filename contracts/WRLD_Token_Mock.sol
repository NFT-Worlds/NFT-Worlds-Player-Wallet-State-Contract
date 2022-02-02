// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract WRLD_Token_Mock is ERC20, ERC20Capped, Ownable, ReentrancyGuard, ERC2771Context {
  uint public feeBps;
  uint public feeFixed;
  uint public feeCap;
  address private feeRecipient;
  address public childChainManagerProxy;

  event TransferRef(address indexed sender, address indexed recipient, uint256 amount, uint256 ref);

  /**
   * address _forwarder: The trusted forwarder contract address (WRLD_Forwarder_Polygon contract)
   * address _depositManager: The trusted polygon contract address for bridge deposits
   */

  constructor(address _forwarder)
  ERC20("NFT Worlds", "WRLD")
  ERC20Capped(5000000000 ether)
  ERC2771Context(_forwarder) {
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
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

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Capped) {
    super._mint(to, amount);
  }
}
