// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "./IERC165.sol";

abstract contract ERC165 is IERC165 {

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 _id)
    public
    virtual
    view
    returns (bool)
  {
    return _id != 0xffffffff && _id == type(IERC165).interfaceId;
  }

}
