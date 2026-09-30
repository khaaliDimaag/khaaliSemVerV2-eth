// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {khaaliSemVerV2} from "../../src/khaaliSemVerV2.sol";
import {IkhaaliSemVerErrorsV1} from "../../src/util/IkhaaliSemVerErrorsV1.sol";

/// @title Harness
/// @notice Deploys `khaaliSemVerV2` at a fixed version.
contract khaaliSemVerV2Harness is khaaliSemVerV2 {
  constructor(string memory _raw) khaaliSemVerV2(_raw) {}
}

/// @title Compare precedence checks
/// @author grok-build (Grok 4.7)
/// @notice Authored by the coding agent, not the semver author.
///         `compare` reports whether the argument has higher precedence
///         than the version stored on the contract. Cases follow SemVer 2.0.0
///         item 11, including the spec's own example chain.
contract CompareCheck is Test, IkhaaliSemVerErrorsV1 {

  function _greater(string memory _stored, string memory _arg) internal returns (bool) {
    return (new khaaliSemVerV2Harness(_stored)).compare(_arg);
  }

  /// @dev Caps gas so an equal pre-release pair that never returns fails the
  ///      assertion instead of burning the whole test's gas.
  function _greaterBounded(string memory _stored, string memory _arg) internal returns (bool) {
    khaaliSemVerV2Harness _h = new khaaliSemVerV2Harness(_stored);
    (bool _ok, bytes memory _data) = address(_h).call{gas: 1_000_000}(
      abi.encodeWithSignature("compare(string)", _arg)
    );
    assertTrue(_ok, string.concat("compare ran out of gas: ", _stored, " vs ", _arg));
    return abi.decode(_data, (bool));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// major, minor, patch — left to right, numerically
  //////////////////////////////////////////////////////////////////////////////

  function test_core_higherFieldWins() public {
    assertTrue(_greater("1.0.0", "2.0.0"));
    assertFalse(_greater("2.0.0", "1.0.0"));

    assertTrue(_greater("2.0.0", "2.1.0"));
    assertFalse(_greater("2.1.0", "2.0.0"));

    assertTrue(_greater("2.1.0", "2.1.1"));
    assertFalse(_greater("2.1.1", "2.1.0"));
  }

  function test_core_lowerFieldDoesNotOverride() public {
    assertFalse(_greater("2.0.0", "1.9.0"));
    assertFalse(_greater("1.2.0", "1.1.9"));
    assertFalse(_greater("2.0.0-alpha", "1.0.0"));
    assertFalse(_greater("1.0.1", "1.0.0-rc.1"));

    // A smaller core field has to win even when the pre-release walk would
    // say the argument is greater.
    assertFalse(_greater("1.2.0-rc.1", "1.1.9"));
    assertFalse(_greater("1.0.1-alpha", "1.0.0"));
    assertFalse(_greater("1.0.1-alpha", "1.0.0-beta"));
  }

  function test_core_equalIsNotGreater() public {
    assertFalse(_greater("1.2.3", "1.2.3"));
    assertFalse(_greater("0.0.0", "0.0.0"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// a pre-release has lower precedence than the normal version
  //////////////////////////////////////////////////////////////////////////////

  function test_releaseGreaterThanPreRelease() public {
    assertTrue(_greater("1.0.0-alpha", "1.0.0"));
    assertTrue(_greater("1.0.0-alpha.1", "1.0.0"));
    assertTrue(_greater("1.0.0-rc.1+build", "1.0.0+zzz"));

    assertFalse(_greater("1.0.0", "1.0.0-alpha"));
    assertFalse(_greater("1.0.0+build", "1.0.0-alpha"));
    assertFalse(_greater("1.0.0", "1.0.0-0"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// spec example:
  ///// 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta
  /////   < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
  //////////////////////////////////////////////////////////////////////////////

  function test_specExampleOrder() public {
    string[8] memory _v = [
      "1.0.0-alpha",
      "1.0.0-alpha.1",
      "1.0.0-alpha.beta",
      "1.0.0-beta",
      "1.0.0-beta.2",
      "1.0.0-beta.11",
      "1.0.0-rc.1",
      "1.0.0"
    ];

    for(uint _i; _i < _v.length; _i++) {
      for(uint _j; _j < _v.length; _j++) {
        if(_i == _j) continue;
        assertEq(
          _greater(_v[_i], _v[_j]),
          _j > _i,
          string.concat("stored ", _v[_i], " arg ", _v[_j])
        );
      }
    }
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// 1. digits compare numerically
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_numeric() public {
    assertTrue(_greater("1.0.0-1", "1.0.0-2"));
    assertFalse(_greater("1.0.0-2", "1.0.0-1"));

    assertTrue(_greater("1.0.0-2", "1.0.0-10"));
    assertFalse(_greater("1.0.0-10", "1.0.0-2"));

    assertTrue(_greater("1.0.0-beta.2", "1.0.0-beta.11"));
    assertFalse(_greater("1.0.0-beta.11", "1.0.0-beta.2"));

    // A dot follows the number, so numeric-ness has to survive the separator.
    assertTrue(_greater("1.0.0-9.a", "1.0.0-10.a"));
    assertFalse(_greater("1.0.0-10.a", "1.0.0-9.a"));

    // Same length, so the digit loop has to keep going past an equal prefix.
    assertTrue(_greater("1.0.0-11", "1.0.0-19"));
    assertFalse(_greater("1.0.0-19", "1.0.0-11"));
    assertTrue(_greater("1.0.0-101", "1.0.0-110"));
    assertFalse(_greater("1.0.0-110", "1.0.0-101"));
    assertTrue(_greater("1.0.0-11.a", "1.0.0-19.a"));
    assertFalse(_greater("1.0.0-19.a", "1.0.0-11.a"));

    // An equal numeric field falls through to the next identifier.
    assertTrue(_greater("1.0.0-10.2", "1.0.0-10.3"));
    assertFalse(_greater("1.0.0-10.3", "1.0.0-10.2"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// 2. letters and hyphens compare in ASCII order
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_ascii() public {
    assertTrue(_greater("1.0.0-alpha", "1.0.0-beta"));
    assertFalse(_greater("1.0.0-beta", "1.0.0-alpha"));

    assertTrue(_greater("1.0.0-A", "1.0.0-a"));
    assertFalse(_greater("1.0.0-a", "1.0.0-A"));

    assertTrue(_greater("1.0.0--", "1.0.0-a"));
    assertFalse(_greater("1.0.0-a", "1.0.0--"));

    assertTrue(_greater("1.0.0-alpha", "1.0.0-alpha1"));
    assertFalse(_greater("1.0.0-alpha1", "1.0.0-alpha"));

    // Shared prefix, then a later byte differs. Length must not decide this.
    assertTrue(_greater("1.0.0-alpha", "1.0.0-alqha"));
    assertFalse(_greater("1.0.0-alqha", "1.0.0-alpha"));
    assertTrue(_greater("1.0.0-ab", "1.0.0-acd"));
    assertFalse(_greater("1.0.0-acd", "1.0.0-ab"));
    assertTrue(_greater("1.0.0-a-b", "1.0.0-a-c"));
    assertFalse(_greater("1.0.0-a-c", "1.0.0-a-b"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// 3. numeric identifiers are always lower than non-numeric ones
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_numericLowerThanNonNumeric() public {
    assertTrue(_greater("1.0.0-1", "1.0.0-a"));
    assertFalse(_greater("1.0.0-a", "1.0.0-1"));

    assertTrue(_greater("1.0.0-1", "1.0.0--"));
    assertFalse(_greater("1.0.0--", "1.0.0-1"));

    assertTrue(_greater("1.0.0-alpha.1", "1.0.0-alpha.beta"));
    assertFalse(_greater("1.0.0-alpha.beta", "1.0.0-alpha.1"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// 4. a larger set wins only when the preceding identifiers are equal
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_largerSet() public {
    assertTrue(_greater("1.0.0-alpha", "1.0.0-alpha.1"));
    assertFalse(_greater("1.0.0-alpha.1", "1.0.0-alpha"));

    assertTrue(_greater("1.0.0-alpha", "1.0.0-alpha.beta"));
    assertFalse(_greater("1.0.0-alpha.beta", "1.0.0-alpha"));

    // More fields do not win when an earlier identifier differs.
    assertFalse(_greater("1.0.0-beta", "1.0.0-alpha.beta"));
    assertTrue(_greater("1.0.0-alpha.beta", "1.0.0-beta"));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// equal pre-release tags are not greater; build metadata is ignored
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_equalIsNotGreater() public {
    assertFalse(_greaterBounded("1.0.0-alpha", "1.0.0-alpha"));
    assertFalse(_greaterBounded("1.0.0-beta.11", "1.0.0-beta.11"));
    assertFalse(_greaterBounded("1.0.0-alpha.1", "1.0.0-alpha.1"));
    assertFalse(_greaterBounded("1.0.0-rc.1+build", "1.0.0-rc.1+other"));
  }

  function test_buildIsIgnored() public {
    assertFalse(_greater("1.0.0+aaa", "1.0.0+zzz"));
    assertFalse(_greater("1.0.0+zzz", "1.0.0+aaa"));
    assertTrue(_greater("1.0.0+zzz", "1.0.1+aaa"));
    assertFalse(_greater("1.0.1+aaa", "1.0.0+zzz"));
  }

  function test_bytesEntry() public {
    khaaliSemVerV2Harness _h = new khaaliSemVerV2Harness("1.0.0-beta.2");
    assertTrue(_h.compare(bytes("1.0.0-beta.11")));
    assertFalse(_h.compare(bytes("1.0.0-alpha")));
  }

  function test_invalidVersionReverts() public {
    khaaliSemVerV2Harness _h = new khaaliSemVerV2Harness("1.0.0");
    vm.expectRevert(VersionCannotBeEmpty.selector);
    _h.compare(string(""));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// properties over random valid versions
  //////////////////////////////////////////////////////////////////////////////

  function testFuzz_antisymmetry(
    uint8 _majA, uint8 _minA, uint16 _patA,
    uint8 _majB, uint8 _minB, uint16 _patB,
    uint256 _salt
  ) public {
    string memory _a = _version(_majA, _minA, _patA, _salt);
    string memory _b = _version(_majB, _minB, _patB, _salt >> 128);

    assertFalse(_greater(_a, _b) && _greater(_b, _a));
  }

  function testFuzz_equalIsNotGreater(uint8 _maj, uint8 _min, uint16 _pat, uint256 _salt) public {
    string memory _v = _version(_maj, _min, _pat, _salt);

    assertFalse(_greater(_v, _v));
    assertFalse(_greater(string.concat(_v, "+aaa"), string.concat(_v, "+zzz")));
  }

  function testFuzz_buildIsIgnored(
    uint8 _majA, uint8 _minA, uint16 _patA,
    uint8 _majB, uint8 _minB, uint16 _patB,
    uint256 _salt
  ) public {
    string memory _a = _version(_majA, _minA, _patA, _salt);
    string memory _b = _version(_majB, _minB, _patB, _salt >> 128);

    assertEq(
      _greater(_a, _b),
      _greater(string.concat(_a, "+aaa"), string.concat(_b, "+zzz"))
    );
  }

  function testFuzz_coreDominatesPreRelease(
    uint8 _majA, uint8 _minA, uint16 _patA,
    uint8 _majB, uint8 _minB, uint16 _patB,
    uint256 _salt
  ) public {
    vm.assume(_majA != _majB || _minA != _minB || _patA != _patB);

    string memory _a = _core(_majA, _minA, _patA);
    string memory _b = _core(_majB, _minB, _patB);

    assertEq(
      _greater(_a, _b),
      _greater(_version(_majA, _minA, _patA, _salt), _version(_majB, _minB, _patB, _salt >> 128))
    );
  }

  function _version(uint8 _maj, uint8 _min, uint16 _pat, uint256 _salt)
    internal
    pure
    returns (string memory)
  {
    string memory _pre = _preRelease(_salt);
    string memory _coreVer = _core(_maj, _min, _pat);
    if(bytes(_pre).length == 0) return _coreVer;
    return string.concat(_coreVer, "-", _pre);
  }

  function _core(uint8 _maj, uint8 _min, uint16 _pat) internal pure returns (string memory) {
    return string.concat(vm.toString(_maj), ".", vm.toString(_min), ".", vm.toString(_pat));
  }

  /// @dev Zero to three identifiers. Digits have no leading zero. Letters may include '-'.
  function _preRelease(uint256 _salt) internal pure returns (string memory pre) {
    uint256 _count = _salt % 4;
    _salt /= 4;

    for(uint256 _i; _i < _count; _i++) {
      string memory _ident = _salt % 2 == 0 ? _numIdent(_salt / 2) : _alphaIdent(_salt / 2);
      _salt >>= 32;
      pre = _i == 0 ? _ident : string.concat(pre, ".", _ident);
    }
  }

  function _numIdent(uint256 _salt) internal pure returns (string memory) {
    if(_salt % 5 == 0) return "0";

    uint256 _len = 1 + (_salt % 4);
    _salt /= 5;

    bytes memory _raw = new bytes(_len);
    _raw[0] = bytes1(uint8(0x31 + (_salt % 9)));
    _salt /= 9;

    for(uint256 _i = 1; _i < _len; _i++) {
      _raw[_i] = bytes1(uint8(0x30 + (_salt % 10)));
      _salt /= 10;
    }

    return string(_raw);
  }

  function _alphaIdent(uint256 _salt) internal pure returns (string memory) {
    bytes memory _alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-";
    uint256 _len = 1 + (_salt % 4);
    _salt /= 4;

    bytes memory _raw = new bytes(_len);
    for(uint256 _i; _i < _len; _i++) {
      _raw[_i] = _alphabet[_salt % _alphabet.length];
      _salt /= _alphabet.length;
    }

    return string(_raw);
  }

}
