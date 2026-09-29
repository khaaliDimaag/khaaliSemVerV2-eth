// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "../eip/IERC165.sol";

/// @title IkhaaliAdmin
/// @notice Utility contract for a two-step handoff to prevent bricks from typos
interface IkhaaliAdmin is IERC165 {

  //////////////////////////////////////////////////////////////////////////////
  ///// Errors
  //////////////////////////////////////////////////////////////////////////////

  error AdminCannotBeZero();
  error AdminFunctionCalledByNonAdmin(address caller, address admin);
  error CallerIsNotAnyAdmin(address caller, address admin, address pending);

  error NewAdminCannotBeZero();
  error NewAdminCannotBeSameAsCurrent();

  error PendingAdminIsUnset();
  error PendingAdminMustAcceptBeforeCalling();
  error OnlyPendingAdminMayAccept(address pending);
  error PendingAdminMustAcceptOrDecline(address pending);

  //////////////////////////////////////////////////////////////////////////////
  ///// Events
  //////////////////////////////////////////////////////////////////////////////

  event AdminNominated(address indexed pendingAdmin);
  event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
  event AdminDeclined(address indexed pendingAdmin, address indexed declinedBy);

  //////////////////////////////////////////////////////////////////////////////
  ///// Getters
  //////////////////////////////////////////////////////////////////////////////

  /// Get the address of the current admin of the contract
  function admin() external view returns (address currentAdmin);

  /// Get the address of a pending admin (or `address(0)`) of the contract
  function pending() external view returns (address pendingAdmin);

  //////////////////////////////////////////////////////////////////////////////
  ///// Main Functionality
  //////////////////////////////////////////////////////////////////////////////

  /// @notice Start the two step handoff to update the admin of the contract
  /// @dev Can only be called by the current contract admin
  /// @dev Emits AdminNominated
  /// @dev Requires pending admin to be unset
  /// @param newAdmin The new admin for the contract
  function updateAdmin(address newAdmin) external;

  /// @notice Accept role of admin
  /// @dev Can only be called by pending admin
  /// @dev Emits AdminUpdated
  function acceptAdmin() external;

  /// @notice Decline or cancel update of contract admin
  /// @dev Can be called by current or pending admin
  /// @dev Emits AdminDeclined
  function declineAdmin() external;
}
