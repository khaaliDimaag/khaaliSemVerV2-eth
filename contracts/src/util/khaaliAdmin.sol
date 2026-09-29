// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IkhaaliAdmin} from "./IkhaaliAdmin.sol";

import {ERC165} from "../eip/ERC165.sol";
import {IERC165} from "../eip/IERC165.sol";

abstract contract khaaliAdmin is IkhaaliAdmin, ERC165 {

  //////////////////////////////////////////////////////////////////////////////
  ///// State Variables
  //////////////////////////////////////////////////////////////////////////////

  address internal currentAdmin;
  address internal pendingAdmin;


  //////////////////////////////////////////////////////////////////////////////
  ///// Modifiers
  //////////////////////////////////////////////////////////////////////////////

  modifier onlyCurrentAdmin() {
    _onlyCurrentAdmin();
    _;
  }

  /// @dev sugar for inheriting contracts
  modifier onlyAdmin() {
    _onlyCurrentAdmin();
    _;
  }

  function _onlyCurrentAdmin() internal view {
    if(msg.sender == pendingAdmin)
      revert PendingAdminMustAcceptBeforeCalling();
    if(msg.sender != currentAdmin)
      revert AdminFunctionCalledByNonAdmin(msg.sender, currentAdmin);
  }

  modifier anyAdmin() {
    _anyAdmin();
    _;
  }

  function _anyAdmin() internal view {
    if (msg.sender != currentAdmin && msg.sender != pendingAdmin)
      revert CallerIsNotAnyAdmin(msg.sender, currentAdmin, pendingAdmin);
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Initializers
  //////////////////////////////////////////////////////////////////////////////

  constructor(address _admin) {
    require(_admin != address(0), AdminCannotBeZero());
    currentAdmin = _admin;
    emit AdminUpdated(address(0), currentAdmin);
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Getters
  //////////////////////////////////////////////////////////////////////////////

  /// @inheritdoc IkhaaliAdmin
  function admin() public view returns (address) {
    return currentAdmin;
  }

  /// @inheritdoc IkhaaliAdmin
  function pending() public view returns (address) {
    return pendingAdmin;
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Main Functionality
  //////////////////////////////////////////////////////////////////////////////

  /// @inheritdoc IkhaaliAdmin
  function updateAdmin(address _new) external onlyCurrentAdmin {
    if(pendingAdmin != address(0))
      revert PendingAdminMustAcceptOrDecline(pendingAdmin);
    if(_new == address(0))
      revert NewAdminCannotBeZero();
    if(_new == currentAdmin)
      revert NewAdminCannotBeSameAsCurrent();

    pendingAdmin = _new;

    emit AdminNominated(pendingAdmin);
  }

  /// @inheritdoc IkhaaliAdmin
  function acceptAdmin() external {
    if(msg.sender != pendingAdmin)
      revert OnlyPendingAdminMayAccept(pendingAdmin);

    address oldAdmin = currentAdmin;
    currentAdmin = pendingAdmin;
    pendingAdmin = address(0);

    emit AdminUpdated(oldAdmin, currentAdmin);
  }

  /// @inheritdoc IkhaaliAdmin
  function declineAdmin() external anyAdmin {
    if(pendingAdmin == address(0))
      revert PendingAdminIsUnset();

    address oldPending = pendingAdmin;
    pendingAdmin = address(0);
    emit AdminDeclined(oldPending, msg.sender);
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// ERC Related
  //////////////////////////////////////////////////////////////////////////////

  /// @dev explicit calls to avoid mid-chain hops forgetting to call `super`
  function supportsInterface(bytes4 _id)
    public
    virtual
    view
    override(ERC165, IERC165)
    returns (bool)
  {
    return _id == type(IkhaaliAdmin).interfaceId
      || ERC165.supportsInterface(_id);
  }

}
