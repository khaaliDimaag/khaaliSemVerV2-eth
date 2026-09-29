// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {khaaliAdmin} from "../src/util/khaaliAdmin.sol";
import {IkhaaliAdmin} from "../src/util/IkhaaliAdmin.sol";
import {IERC165} from "../src/eip/IERC165.sol";

/// @title Harness
/// @notice Deploys `khaaliAdmin` and exposes its modifiers.
///         `vm.expectRevert` only catches external calls.
contract khaaliAdminHarness is khaaliAdmin {

  constructor(address _admin) khaaliAdmin(_admin) {}

  //////////////////////////////////////////////////////////////////////////////
  ///// expose modifiers to test explicitly
  //////////////////////////////////////////////////////////////////////////////

  function gatedOnlyCurrentAdmin() external view onlyCurrentAdmin {}

  function gatedOnlyAdmin() external view onlyAdmin {}

  function gatedAnyAdmin() external view anyAdmin {}

}

/// @title khaaliAdmin tests
/// @author grok-build (Grok 4.7)
/// @notice Authored by the coding agent, not the admin-contract author.
///         One behavior of the handoff at a time: construct, nominate,
///         accept, decline, then the gates around those calls.
contract khaaliAdminTest is Test {

  // Same signatures as IkhaaliAdmin, so `expectEmit` can record them here.
  event AdminNominated(address indexed pendingAdmin);
  event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
  event AdminDeclined(address indexed pendingAdmin, address indexed declinedBy);

  address internal current;
  address internal nominee;
  address internal stranger;

  khaaliAdminHarness internal harness;

  function setUp() public {
    current = makeAddr("current");
    nominee = makeAddr("nominee");
    stranger = makeAddr("stranger");
    harness = new khaaliAdminHarness(current);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// constructor(address)
  //////////////////////////////////////////////////////////////////////////////

  function test_constructor() public {
    vm.expectRevert(IkhaaliAdmin.AdminCannotBeZero.selector);
    new khaaliAdminHarness(address(0));

    vm.expectEmit(true, true, false, true);
    emit AdminUpdated(address(0), nominee);

    khaaliAdminHarness fresh = new khaaliAdminHarness(nominee);
    assertEq(fresh.admin(), nominee);
    assertEq(fresh.pending(), address(0));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// admin() / pending()
  //////////////////////////////////////////////////////////////////////////////

  function test_getters() public view {
    assertEq(harness.admin(), current);
    assertEq(harness.pending(), address(0));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// updateAdmin(address)
  /////   caller is current, pending is unset, nominee is a fresh non-zero address
  //////////////////////////////////////////////////////////////////////////////

  function test_updateAdmin() public {
    vm.expectEmit(true, false, false, true, address(harness));
    emit AdminNominated(nominee);

    vm.prank(current);
    harness.updateAdmin(nominee);

    assertEq(harness.admin(), current);
    assertEq(harness.pending(), nominee);
  }

  function test_updateAdmin_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.updateAdmin(nominee);
    assertEq(harness.pending(), address(0));

    vm.expectRevert(IkhaaliAdmin.NewAdminCannotBeZero.selector);
    vm.prank(current);
    harness.updateAdmin(address(0));

    vm.expectRevert(IkhaaliAdmin.NewAdminCannotBeSameAsCurrent.selector);
    vm.prank(current);
    harness.updateAdmin(current);

    vm.prank(current);
    harness.updateAdmin(nominee);

    // Nominee is pending, so the pending check wins over the non-admin check.
    vm.expectRevert(IkhaaliAdmin.PendingAdminMustAcceptBeforeCalling.selector);
    vm.prank(nominee);
    harness.updateAdmin(stranger);

    // A stranger is rejected before the outstanding-pending check.
    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.updateAdmin(stranger);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.PendingAdminMustAcceptOrDecline.selector,
      nominee
    ));
    vm.prank(current);
    harness.updateAdmin(makeAddr("other"));

    assertEq(harness.admin(), current);
    assertEq(harness.pending(), nominee);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// acceptAdmin()
  /////   caller is the pending admin
  //////////////////////////////////////////////////////////////////////////////

  function test_acceptAdmin() public {
    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.expectEmit(true, true, false, true, address(harness));
    emit AdminUpdated(current, nominee);

    vm.prank(nominee);
    harness.acceptAdmin();

    assertEq(harness.admin(), nominee);
    assertEq(harness.pending(), address(0));
  }

  function test_acceptAdmin_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      address(0)
    ));
    vm.prank(current);
    harness.acceptAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      address(0)
    ));
    vm.prank(stranger);
    harness.acceptAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      nominee
    ));
    vm.prank(current);
    harness.acceptAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      nominee
    ));
    vm.prank(stranger);
    harness.acceptAdmin();

    vm.prank(nominee);
    harness.acceptAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      address(0)
    ));
    vm.prank(nominee);
    harness.acceptAdmin();

    assertEq(harness.admin(), nominee);
    assertEq(harness.pending(), address(0));
  }

  /// @dev Pending is unset, so `msg.sender == pending` holds for the zero address.
  function test_acceptAdmin_zeroAddressMatchesUnsetPending() public {
    vm.expectEmit(true, true, false, true, address(harness));
    emit AdminUpdated(current, address(0));

    vm.prank(address(0));
    harness.acceptAdmin();

    assertEq(harness.admin(), address(0));
    assertEq(harness.pending(), address(0));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// declineAdmin()
  /////   caller is current or pending, and a nomination is outstanding
  //////////////////////////////////////////////////////////////////////////////

  function test_declineAdmin_byCurrent() public {
    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.expectEmit(true, true, false, true, address(harness));
    emit AdminDeclined(nominee, current);

    vm.prank(current);
    harness.declineAdmin();

    assertEq(harness.admin(), current);
    assertEq(harness.pending(), address(0));

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      nominee,
      current,
      address(0)
    ));
    vm.prank(nominee);
    harness.declineAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);
    assertEq(harness.pending(), nominee);
  }

  function test_declineAdmin_byNominee() public {
    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.expectEmit(true, true, false, true, address(harness));
    emit AdminDeclined(nominee, nominee);

    vm.prank(nominee);
    harness.declineAdmin();

    assertEq(harness.admin(), current);
    assertEq(harness.pending(), address(0));

    vm.prank(current);
    harness.updateAdmin(nominee);
    assertEq(harness.pending(), nominee);
  }

  function test_declineAdmin_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      stranger,
      current,
      address(0)
    ));
    vm.prank(stranger);
    harness.declineAdmin();

    vm.expectRevert(IkhaaliAdmin.PendingAdminIsUnset.selector);
    vm.prank(current);
    harness.declineAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      stranger,
      current,
      nominee
    ));
    vm.prank(stranger);
    harness.declineAdmin();

    vm.prank(current);
    harness.declineAdmin();

    vm.expectRevert(IkhaaliAdmin.PendingAdminIsUnset.selector);
    vm.prank(current);
    harness.declineAdmin();

    assertEq(harness.admin(), current);
    assertEq(harness.pending(), address(0));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// onlyCurrentAdmin / onlyAdmin / anyAdmin
  //////////////////////////////////////////////////////////////////////////////

  function test_onlyCurrentAdmin() public {
    vm.prank(current);
    harness.gatedOnlyCurrentAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.gatedOnlyCurrentAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);

    // An outstanding nominee does not lock the current admin out.
    vm.prank(current);
    harness.gatedOnlyCurrentAdmin();

    vm.expectRevert(IkhaaliAdmin.PendingAdminMustAcceptBeforeCalling.selector);
    vm.prank(nominee);
    harness.gatedOnlyCurrentAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.gatedOnlyCurrentAdmin();
  }

  function test_onlyAdmin() public {
    vm.prank(current);
    harness.gatedOnlyAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.gatedOnlyAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.prank(current);
    harness.gatedOnlyAdmin();

    vm.expectRevert(IkhaaliAdmin.PendingAdminMustAcceptBeforeCalling.selector);
    vm.prank(nominee);
    harness.gatedOnlyAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      stranger,
      current
    ));
    vm.prank(stranger);
    harness.gatedOnlyAdmin();
  }

  function test_anyAdmin() public {
    vm.prank(current);
    harness.gatedAnyAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      stranger,
      current,
      address(0)
    ));
    vm.prank(stranger);
    harness.gatedAnyAdmin();

    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.prank(current);
    harness.gatedAnyAdmin();

    vm.prank(nominee);
    harness.gatedAnyAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      stranger,
      current,
      nominee
    ));
    vm.prank(stranger);
    harness.gatedAnyAdmin();
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Handoff: nominate, accept, previous admin is out, a later hop works
  //////////////////////////////////////////////////////////////////////////////

  function test_handoff() public {
    address third = makeAddr("third");

    vm.prank(current);
    harness.updateAdmin(nominee);

    vm.prank(nominee);
    harness.acceptAdmin();

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
      current,
      nominee
    ));
    vm.prank(current);
    harness.updateAdmin(third);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      current,
      nominee,
      address(0)
    ));
    vm.prank(current);
    harness.declineAdmin();

    vm.prank(nominee);
    harness.gatedOnlyCurrentAdmin();

    vm.prank(nominee);
    harness.updateAdmin(third);

    vm.prank(third);
    harness.acceptAdmin();
    assertEq(harness.admin(), third);
    assertEq(harness.pending(), address(0));

    // A previous admin is a legal nominee once they are no longer current.
    vm.prank(third);
    harness.updateAdmin(current);

    vm.prank(current);
    harness.acceptAdmin();
    assertEq(harness.admin(), current);
    assertEq(harness.pending(), address(0));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// supportsInterface(bytes4)
  /////   IkhaaliAdmin's id, plus ERC165's check for IERC165
  //////////////////////////////////////////////////////////////////////////////

  function test_supportsInterface() public view {
    bytes4 adminId = IkhaaliAdmin.admin.selector
      ^ IkhaaliAdmin.pending.selector
      ^ IkhaaliAdmin.updateAdmin.selector
      ^ IkhaaliAdmin.acceptAdmin.selector
      ^ IkhaaliAdmin.declineAdmin.selector;

    assertEq(type(IkhaaliAdmin).interfaceId, adminId);
    assertEq(type(IERC165).interfaceId, bytes4(0x01ffc9a7));

    assertTrue(harness.supportsInterface(type(IkhaaliAdmin).interfaceId));
    assertTrue(harness.supportsInterface(type(IERC165).interfaceId));
    assertFalse(harness.supportsInterface(bytes4(0xffffffff)));
    assertFalse(harness.supportsInterface(bytes4(0)));
    assertFalse(harness.supportsInterface(IkhaaliAdmin.admin.selector));
  }

  /// @dev ERC-165 requires this call to stay under 30,000 gas.
  function test_supportsInterface_gas() public view {
    uint256 start = gasleft();
    harness.supportsInterface(type(IkhaaliAdmin).interfaceId);
    assertLt(start - gasleft(), 30_000);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Fuzz: Forge supplies the caller or the nominee.
  //////////////////////////////////////////////////////////////////////////////

  function testFuzz_updateAdmin(address _new) public {
    khaaliAdminHarness fresh = new khaaliAdminHarness(current);

    if(_new == address(0)) {
      vm.expectRevert(IkhaaliAdmin.NewAdminCannotBeZero.selector);
      vm.prank(current);
      fresh.updateAdmin(_new);
      return;
    }

    if(_new == current) {
      vm.expectRevert(IkhaaliAdmin.NewAdminCannotBeSameAsCurrent.selector);
      vm.prank(current);
      fresh.updateAdmin(_new);
      return;
    }

    vm.expectEmit(true, false, false, true, address(fresh));
    emit AdminNominated(_new);

    vm.prank(current);
    fresh.updateAdmin(_new);

    assertEq(fresh.admin(), current);
    assertEq(fresh.pending(), _new);
  }

  function testFuzz_acceptAdmin_unsetPending(address _caller) public {
    vm.assume(_caller != address(0));

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      address(0)
    ));
    vm.prank(_caller);
    harness.acceptAdmin();
  }

  function testFuzz_acceptAdmin_onlyNominee(address _caller) public {
    vm.assume(_caller != nominee);

    khaaliAdminHarness fresh = new khaaliAdminHarness(current);
    vm.prank(current);
    fresh.updateAdmin(nominee);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.OnlyPendingAdminMayAccept.selector,
      nominee
    ));
    vm.prank(_caller);
    fresh.acceptAdmin();

    assertEq(fresh.admin(), current);
    assertEq(fresh.pending(), nominee);
  }

  function testFuzz_declineAdmin_onlyAnyAdmin(address _caller) public {
    vm.assume(_caller != current && _caller != nominee);

    khaaliAdminHarness fresh = new khaaliAdminHarness(current);
    vm.prank(current);
    fresh.updateAdmin(nominee);

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      _caller,
      current,
      nominee
    ));
    vm.prank(_caller);
    fresh.declineAdmin();

    assertEq(fresh.pending(), nominee);
  }

  function testFuzz_onlyCurrentAdmin(address _caller) public {
    khaaliAdminHarness fresh = new khaaliAdminHarness(current);
    vm.prank(current);
    fresh.updateAdmin(nominee);

    if(_caller == nominee) {
      vm.expectRevert(IkhaaliAdmin.PendingAdminMustAcceptBeforeCalling.selector);
      vm.prank(_caller);
      fresh.gatedOnlyCurrentAdmin();
      return;
    }

    if(_caller != current) {
      vm.expectRevert(abi.encodeWithSelector(
        IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
        _caller,
        current
      ));
      vm.prank(_caller);
      fresh.gatedOnlyCurrentAdmin();
      return;
    }

    vm.prank(_caller);
    fresh.gatedOnlyCurrentAdmin();
  }

  function testFuzz_onlyAdmin(address _caller) public {
    khaaliAdminHarness fresh = new khaaliAdminHarness(current);
    vm.prank(current);
    fresh.updateAdmin(nominee);

    if(_caller == nominee) {
      vm.expectRevert(IkhaaliAdmin.PendingAdminMustAcceptBeforeCalling.selector);
      vm.prank(_caller);
      fresh.gatedOnlyAdmin();
      return;
    }

    if(_caller != current) {
      vm.expectRevert(abi.encodeWithSelector(
        IkhaaliAdmin.AdminFunctionCalledByNonAdmin.selector,
        _caller,
        current
      ));
      vm.prank(_caller);
      fresh.gatedOnlyAdmin();
      return;
    }

    vm.prank(_caller);
    fresh.gatedOnlyAdmin();
  }

  function testFuzz_anyAdmin(address _caller) public {
    khaaliAdminHarness fresh = new khaaliAdminHarness(current);
    vm.prank(current);
    fresh.updateAdmin(nominee);

    if(_caller == current || _caller == nominee) {
      vm.prank(_caller);
      fresh.gatedAnyAdmin();
      return;
    }

    vm.expectRevert(abi.encodeWithSelector(
      IkhaaliAdmin.CallerIsNotAnyAdmin.selector,
      _caller,
      current,
      nominee
    ));
    vm.prank(_caller);
    fresh.gatedAnyAdmin();
  }

  function testFuzz_supportsInterface(bytes4 _id) public view {
    bool expected = _id == type(IkhaaliAdmin).interfaceId
      || (_id != 0xffffffff && _id == type(IERC165).interfaceId);

    assertEq(harness.supportsInterface(_id), expected);
  }

}
