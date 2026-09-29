// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IkhaaliSemVerV2} from "./IkhaaliSemVerV2.sol";
import {FunctionDeprecation, FunctionStatus} from "./IkhaaliSemVerV2.sol";

import {SemVerToken, SemVer} from "./util/khaaliSemVerV2Types.sol";
import {Major, Minor, Patch} from "./util/khaaliSemVerV2Types.sol";
import {khaaliSemVerParserV1} from "./util/khaaliSemVerParserV1.sol";

import {khaaliAdmin} from "./util/khaaliAdmin.sol";

import {ERC165} from "./eip/ERC165.sol";
import {IERC165} from "./eip/IERC165.sol";

/// @dev Marked `abstract` since this is not meant to be standalone
abstract contract khaaliSemVerV2 is
  IkhaaliSemVerV2,
  ERC165,
  khaaliSemVerParserV1,
  khaaliAdmin
{

  SemVer private version;
  mapping(bytes4 => FunctionStatus) private functionStatusFull;
  mapping(bytes4 => FunctionDeprecation) private functionStatus;


  //////////////////////////////////////////////////////////////////////////////
  ///// Modifiers
  //////////////////////////////////////////////////////////////////////////////

  modifier funcIsActive(bytes4 selector) {
    _funcIsActive(selector);
    _;
  }

  function _funcIsActive(bytes4 selector) internal view {
    FunctionStatus memory _f = functionStatusFull[selector];

    if(_f.status == FunctionDeprecation.UNIMPLEMENTED)
      revert FunctionUnimplemented(selector);
    if(_f.status == FunctionDeprecation.REMOVED)
      revert FunctionDeprecated(selector);
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Initializers
  //////////////////////////////////////////////////////////////////////////////

  constructor(string memory _raw) khaaliAdmin(msg.sender) {
    version = parseVersion(bytes(_raw));
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// External Functions
  //////////////////////////////////////////////////////////////////////////////

  function pretty() public view returns (string memory) {

  }

  function semver() public view returns (string memory) {

  }

  function compare(string memory _raw) public returns (bool isGreater) {
    return compare(bytes(_raw));
  }


  function compare(bytes memory _raw) public returns (bool isGreater) {

    SemVer memory _v = parseVersion(_raw);

  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Admin Only Functions
  //////////////////////////////////////////////////////////////////////////////

  function deprecate() external onlyAdmin {

  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Internal Functions
  //////////////////////////////////////////////////////////////////////////////


  //////////////////////////////////////////////////////////////////////////////
  ///// ERC Related
  //////////////////////////////////////////////////////////////////////////////

  /// @dev explicit calls to avoid mid-chain hops forgetting to call `super`
  function supportsInterface(bytes4 _id)
    public
    virtual
    view
    override(khaaliAdmin, ERC165, IERC165)
    returns (bool)
  {
    return _id == type(IkhaaliSemVerV2).interfaceId
      || khaaliAdmin.supportsInterface(_id)
      || ERC165.supportsInterface(_id); // @dev redundant, should be removed
  }

}
