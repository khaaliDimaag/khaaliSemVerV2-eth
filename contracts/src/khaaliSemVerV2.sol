// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IkhaaliSemVerV2} from "./IkhaaliSemVerV2.sol";
import {FunctionDeprecation, FunctionStatus} from "./IkhaaliSemVerV2.sol";

import {SemVerToken, SemVer} from "./util/khaaliSemVerV2Types.sol";
import {Major, Minor, Patch} from "./util/khaaliSemVerV2Types.sol";
import {khaaliSemVerParserV1} from "./util/khaaliSemVerParserV1.sol";

import {ERC165} from "./eip/ERC165.sol";
import {IERC165} from "./eip/IERC165.sol";

/// @dev Marked `abstract` since this is not meant to be standalone
abstract contract khaaliSemVerV2 is
  IkhaaliSemVerV2,
  ERC165,
  khaaliSemVerParserV1
{

  SemVer private version;
  address private admin;
  address private pendingAdmin;
  mapping(bytes4 => FunctionStatus) private functionStatusFull;
  mapping(bytes4 => FunctionDeprecation) private functionStatus;


  //////////////////////////////////////////////////////////////////////////////
  ///// Modifiers
  //////////////////////////////////////////////////////////////////////////////

  modifier onlyAdmin() {
    _onlyAdmin();
    _;
  }

  // @dev this contract should not be used in place of Ownable or AccessControl
  function _onlyAdmin() private view {
    if(msg.sender == pendingAdmin) revert PendingAdminMustAcceptBeforeCalling();
    require(
      msg.sender == admin,
      AdminFunctionCalledByNonAdmin(msg.sender, admin)
    );
  }

  modifier anyAdmin() {
    _anyAdmin();
    _;
  }

  // @dev this contract should not be used in place of Ownable or AccessControl
  function _anyAdmin() private view {
    require(
      msg.sender == admin || msg.sender == pendingAdmin,
      "Not an admin or pending admin!"
    );
  }

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

  constructor(string memory _raw) {
    version = parseVersion(bytes(_raw));
    admin = msg.sender;
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
  ///// Contract Upkeep
  //////////////////////////////////////////////////////////////////////////////

  function updateAdmin(address _new) external onlyAdmin {
    require(
      pendingAdmin == address(0),
      PendingAdminMustAcceptOrDecline(pendingAdmin)
    );

    pendingAdmin = _new;
  }

  function acceptAdmin() external {
    require(
      pendingAdmin == msg.sender,
      AdminFunctionCalledByNonAdmin(msg.sender, pendingAdmin)
    );

    admin = pendingAdmin;
    pendingAdmin = address(0);
  }

  function declineAdmin() external anyAdmin {
    pendingAdmin = address(0);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Internal Functions
  //////////////////////////////////////////////////////////////////////////////


  //////////////////////////////////////////////////////////////////////////////
  ///// Private Helpers
  //////////////////////////////////////////////////////////////////////////////


}
