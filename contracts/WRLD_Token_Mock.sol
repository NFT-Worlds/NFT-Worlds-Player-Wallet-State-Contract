// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

// See https://docs.polygon.technology/docs/develop/ethereum-polygon/mintable-assets/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract WRLD_Token_Mock is
  ERC20, ERC20Capped
{

  constructor()
  ERC20("NFT Worlds", "WRLD")
  ERC20Capped(5000000000 ether) {}

  /**
   * Overrides
   */

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Capped) {
    super._mint(to, amount);
  }
}
