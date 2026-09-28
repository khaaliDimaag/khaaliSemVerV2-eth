// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {khaaliSemVerParserV1} from "../src/util/khaaliSemVerParserV1.sol";
import {IkhaaliSemVerErrorsV1} from "../src/util/IkhaaliSemVerErrorsV1.sol";
import {SemVer, Major, Minor, Patch} from "../src/util/khaaliSemVerV2Types.sol";

/// @title Harness
/// @notice Exposes the internal parser.
///         `vm.expectRevert` only catches external calls.
contract khaaliSemVerParserV1Harness is khaaliSemVerParserV1 {

  function parse(string memory _raw) external pure returns (SemVer memory) {
    return parseVersion(bytes(_raw));
  }

}

/// @title khaaliSemVerParserV1 tests
/// @author opencode (Grok 4.7)
/// @notice Authored by the coding agent, not the parser author.
///         Cases follow the SemVer 2.0.0 BNF, one production at a time.
contract khaaliSemVerParserV1Test is Test, IkhaaliSemVerErrorsV1 {

  khaaliSemVerParserV1Harness internal harness;

  function setUp() public {
    harness = new khaaliSemVerParserV1Harness();
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <numeric identifier> ::= "0" | <positive digit> | <positive digit> <digits>
  //////////////////////////////////////////////////////////////////////////////

  function test_numericIdentifier() public view {
    _expect("0.0.0", 0, 0, 0, "", "");
    _expect("1.2.3", 1, 2, 3, "", "");
    _expect("9.8.7", 9, 8, 7, "", "");
    _expect("10.20.30", 10, 20, 30, "", "");
    _expect("255.255.65535", 255, 255, 65535, "", "");
  }

  function testFuzz_numericIdentifier(uint8 _major, uint8 _minor, uint16 _patch) public view {
    string memory _raw = string.concat(
      vm.toString(_major),
      ".",
      vm.toString(_minor),
      ".",
      vm.toString(_patch)
    );

    _expect(_raw, _major, _minor, _patch, "", "");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <version core> ::= <major> "." <minor> "." <patch>
  //////////////////////////////////////////////////////////////////////////////

  function test_versionCore() public view {
    _expect("1.2.3", 1, 2, 3, "", "");
    _expect("0.1.0", 0, 1, 0, "", "");
    _expect("1.0.0", 1, 0, 0, "", "");
    _expect("2.0.0", 2, 0, 0, "", "");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <alphanumeric identifier>
  /////   <non-digit>
  /////   <non-digit> <identifier characters>
  /////   <identifier characters> <non-digit>
  /////   <identifier characters> <non-digit> <identifier characters>
  ///// <non-digit> ::= <letter> | "-"
  ///// <letter> ::= "A".."Z" | "a".."z"
  //////////////////////////////////////////////////////////////////////////////

  function test_alphanumeric_nonDigit() public view {
    _expect("1.0.0-a", 1, 0, 0, "a", "");
    _expect("1.0.0-z", 1, 0, 0, "z", "");
    _expect("1.0.0-A", 1, 0, 0, "A", "");
    _expect("1.0.0-Z", 1, 0, 0, "Z", "");
    _expect("1.0.0--", 1, 0, 0, "-", "");

    _expect("1.0.0+a", 1, 0, 0, "", "a");
    _expect("1.0.0+z", 1, 0, 0, "", "z");
    _expect("1.0.0+A", 1, 0, 0, "", "A");
    _expect("1.0.0+Z", 1, 0, 0, "", "Z");
    _expect("1.0.0+-", 1, 0, 0, "", "-");
  }

  function test_alphanumeric_nonDigitThenChars() public view {
    _expect("1.0.0-a1", 1, 0, 0, "a1", "");
    _expect("1.0.0-A0", 1, 0, 0, "A0", "");
    _expect("1.0.0--1", 1, 0, 0, "-1", "");
    _expect("1.0.0-a-", 1, 0, 0, "a-", "");

    _expect("1.0.0+a1", 1, 0, 0, "", "a1");
    _expect("1.0.0+A0", 1, 0, 0, "", "A0");
    _expect("1.0.0+-1", 1, 0, 0, "", "-1");
    _expect("1.0.0+a-", 1, 0, 0, "", "a-");
  }

  function test_alphanumeric_charsThenNonDigit() public view {
    _expect("1.0.0-1a", 1, 0, 0, "1a", "");
    _expect("1.0.0-1A", 1, 0, 0, "1A", "");
    _expect("1.0.0-0a", 1, 0, 0, "0a", "");
    _expect("1.0.0-1-", 1, 0, 0, "1-", "");

    _expect("1.0.0+1a", 1, 0, 0, "", "1a");
    _expect("1.0.0+1A", 1, 0, 0, "", "1A");
    _expect("1.0.0+0a", 1, 0, 0, "", "0a");
    _expect("1.0.0+1-", 1, 0, 0, "", "1-");
  }

  function test_alphanumeric_charsNonDigitChars() public view {
    _expect("1.0.0-1a2", 1, 0, 0, "1a2", "");
    _expect("1.0.0-0a1", 1, 0, 0, "0a1", "");
    _expect("1.0.0-rc-1", 1, 0, 0, "rc-1", "");
    _expect("1.0.0-a-b", 1, 0, 0, "a-b", "");
    _expect("1.0.0-x-y-z.--", 1, 0, 0, "x-y-z.--", "");

    _expect("1.0.0+1a2", 1, 0, 0, "", "1a2");
    _expect("1.0.0+0a1", 1, 0, 0, "", "0a1");
    _expect("1.0.0+build-1", 1, 0, 0, "", "build-1");
    _expect("1.0.0+21AF26D3----117B344092BD", 1, 0, 0, "", "21AF26D3----117B344092BD");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <pre-release identifier> ::= <alphanumeric identifier> | <numeric identifier>
  ///// <pre-release> ::= <dot-separated pre-release identifiers>
  //////////////////////////////////////////////////////////////////////////////

  function test_preRelease_numeric() public view {
    _expect("1.0.0-0", 1, 0, 0, "0", "");
    _expect("1.0.0-1", 1, 0, 0, "1", "");
    _expect("1.0.0-10", 1, 0, 0, "10", "");
    _expect("1.0.0-0.3.7", 1, 0, 0, "0.3.7", "");
    _expect("1.0.0-alpha.0", 1, 0, 0, "alpha.0", "");
    _expect("1.0.0-alpha.10", 1, 0, 0, "alpha.10", "");
  }

  function test_preRelease_dotSeparated() public view {
    _expect("1.0.0-alpha", 1, 0, 0, "alpha", "");
    _expect("1.0.0-alpha.1", 1, 0, 0, "alpha.1", "");
    _expect("1.0.0-alpha.beta", 1, 0, 0, "alpha.beta", "");
    _expect("1.0.0-x.7.z.92", 1, 0, 0, "x.7.z.92", "");
    _expect("1.0.0-rc.1", 1, 0, 0, "rc.1", "");
    _expect("1.2.3-alpha.0a", 1, 2, 3, "alpha.0a", "");
    _expect("1.1.1--.-", 1, 1, 1, "-.-", "");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <build identifier> ::= <alphanumeric identifier> | <digits>
  ///// <digits> may include leading zeroes. <numeric identifier> may not.
  //////////////////////////////////////////////////////////////////////////////

  function test_build_digits() public view {
    _expect("1.0.0+0", 1, 0, 0, "", "0");
    _expect("1.0.0+1", 1, 0, 0, "", "1");
    _expect("1.0.0+00", 1, 0, 0, "", "00");
    _expect("1.0.0+01", 1, 0, 0, "", "01");
    _expect("1.0.0+001", 1, 0, 0, "", "001");
    _expect("1.0.0+20130313144700", 1, 0, 0, "", "20130313144700");
    _expect("1.2.3+build.01", 1, 2, 3, "", "build.01");
    _expect("1.2.3+build.00", 1, 2, 3, "", "build.00");
  }

  function test_build_dotSeparated() public view {
    _expect("1.0.0+build", 1, 0, 0, "", "build");
    _expect("1.0.0+build.1", 1, 0, 0, "", "build.1");
    _expect("1.0.0+exp.sha.5114f85", 1, 0, 0, "", "exp.sha.5114f85");
    _expect("1.0.0+a.b.c", 1, 0, 0, "", "a.b.c");
    _expect("1.0.0+--", 1, 0, 0, "", "--");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// <valid semver>
  /////   <version core>
  /////   <version core> "-" <pre-release>
  /////   <version core> "+" <build>
  /////   <version core> "-" <pre-release> "+" <build>
  //////////////////////////////////////////////////////////////////////////////

  function test_validSemver() public view {
    _expect("1.2.3", 1, 2, 3, "", "");
    _expect("1.2.3-alpha", 1, 2, 3, "alpha", "");
    _expect("1.2.3+build", 1, 2, 3, "", "build");
    _expect("1.2.3-alpha+build", 1, 2, 3, "alpha", "build");
    _expect("1.0.0-alpha+001", 1, 0, 0, "alpha", "001");
    _expect("1.0.0-beta+exp.sha.5114f85", 1, 0, 0, "beta", "exp.sha.5114f85");
    _expect("1.2.3-rc.1+build.01", 1, 2, 3, "rc.1", "build.01");
    _expect("1.2.3-0.rc-1.A+-0.01.Z", 1, 2, 3, "0.rc-1.A", "-0.01.Z");
    _expect("1.1.1--.-+-", 1, 1, 1, "-.-", "-");
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Invalid: empty, incomplete, empty identifier
  //////////////////////////////////////////////////////////////////////////////

  function test_emptyVersion() public {
    _reverts("", VersionCannotBeEmpty.selector);
  }

  function test_incompleteCore() public {
    _reverts("1", VersionCoreIsIncomplete.selector);
    _reverts("1.2", VersionCoreIsIncomplete.selector);
    _reverts("1.", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.", IdentifierCannotBeEmpty.selector);
  }

  function test_emptyIdentifier() public {
    _reverts(".1.2.3", IdentifierCannotBeEmpty.selector);
    _reverts("1..2.3", IdentifierCannotBeEmpty.selector);
    _reverts("1.2..3", IdentifierCannotBeEmpty.selector);

    _reverts("1.2.3-", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3+", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-+x", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-+", IdentifierCannotBeEmpty.selector);

    _reverts("1.0.0-.alpha", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-alpha.", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-alpha..1", IdentifierCannotBeEmpty.selector);

    _reverts("1.2.3+.", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3+build.", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3+build..1", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-alpha+", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-alpha+.", IdentifierCannotBeEmpty.selector);
    _reverts("1.2.3-alpha+build.", IdentifierCannotBeEmpty.selector);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Invalid: leading zeroes are forbidden on <numeric identifier> only
  //////////////////////////////////////////////////////////////////////////////

  function test_leadingZeroes() public {
    _reverts("01.2.3", NumericCannotHaveLeadingZeroes.selector);
    _reverts("1.02.3", NumericCannotHaveLeadingZeroes.selector);
    _reverts("1.2.03", NumericCannotHaveLeadingZeroes.selector);
    _reverts("00.0.0", NumericCannotHaveLeadingZeroes.selector);

    _reverts("1.2.3-01", NumericCannotHaveLeadingZeroes.selector);
    _reverts("1.2.3-00", NumericCannotHaveLeadingZeroes.selector);
    _reverts("1.0.0-alpha.01", NumericCannotHaveLeadingZeroes.selector);
    _reverts("1.0.0-0.01", NumericCannotHaveLeadingZeroes.selector);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Invalid: core width, separator, non-digit, token, leftover
  //////////////////////////////////////////////////////////////////////////////

  function test_coreTooHigh() public {
    _reverts(
      "256.0.0",
      abi.encodeWithSelector(VersionCoreTooHigh.selector, type(uint8).max, 256)
    );
    _reverts(
      "1.256.0",
      abi.encodeWithSelector(VersionCoreTooHigh.selector, type(uint8).max, 256)
    );
    _reverts(
      "1.2.65536",
      abi.encodeWithSelector(VersionCoreTooHigh.selector, type(uint16).max, 65536)
    );
    _reverts(
      "1000.0.0",
      abi.encodeWithSelector(VersionCoreTooHigh.selector, type(uint8).max, 1000)
    );
  }

  function test_badCoreSeparator() public {
    _reverts(
      "1-2.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("-"))
    );
    _reverts(
      "1.2-3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("-"))
    );
    _reverts(
      "1+2.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("+"))
    );
    _reverts(
      "1.2+3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("+"))
    );
    _reverts(
      "1a.2.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("a"))
    );
    _reverts(
      "1.2a.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("a"))
    );
    _reverts(
      "1A.2.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("A"))
    );
    _reverts(
      "1.2A.3",
      abi.encodeWithSelector(InvalidCoreSeparator.selector, bytes1("A"))
    );
  }

  function test_nonDigitInCore() public {
    _reverts("1.2.3a", VersionCoreCannotHaveNonDigit.selector);
    _reverts("1.2.3A", VersionCoreCannotHaveNonDigit.selector);
    _reverts("1.2.3.4", VersionCoreCannotHaveNonDigit.selector);
    _reverts("1.2.3.4-alpha", VersionCoreCannotHaveNonDigit.selector);
  }

  function test_invalidToken() public {
    _reverts(
      "1.2.3_beta",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1("_"))
    );
    _reverts(
      "1.2.3-alpha_1",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1("_"))
    );
    _reverts(
      "1.2.3+build_1",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1("_"))
    );
    _reverts(
      "1.2.3 ",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1(" "))
    );
    _reverts(
      "1.2.3-alpha ",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1(" "))
    );
    _reverts(
      "1.2.3+build ",
      abi.encodeWithSelector(InvalidSemVerToken.selector, bytes1(" "))
    );
    _reverts("v1.2.3", IdentifierCannotBeEmpty.selector);
  }

  function test_versionTooLong() public {
    _reverts("1.2.3+build+extra", VersionTooLong.selector);
    _reverts("1.2.3-alpha+build+extra", VersionTooLong.selector);
    _reverts("1.2.3-alpha+build+", VersionTooLong.selector);
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Fuzz: Forge supplies the inputs. The helpers build a grammar string.
  //////////////////////////////////////////////////////////////////////////////

  function testFuzz_preRelease(uint8 _count, uint256 _salt) public view {
    _count = uint8(bound(_count, 1, 4));
    (string memory pre,) = _identList(_count, _salt, true);
    _expect(string.concat("1.2.3-", pre), 1, 2, 3, pre, "");
  }

  function testFuzz_build(uint8 _count, uint256 _salt) public view {
    _count = uint8(bound(_count, 1, 4));
    (string memory build,) = _identList(_count, _salt, false);
    _expect(string.concat("1.2.3+", build), 1, 2, 3, "", build);
  }

  function testFuzz_preAndBuild(
    uint8 _preCount,
    uint8 _buildCount,
    uint256 _salt
  ) public view {
    _preCount = uint8(bound(_preCount, 1, 3));
    _buildCount = uint8(bound(_buildCount, 1, 3));

    (string memory pre, uint256 salt) = _identList(_preCount, _salt, true);
    (string memory build,) = _identList(_buildCount, salt, false);

    _expect(string.concat("1.2.3-", pre, "+", build), 1, 2, 3, pre, build);
  }

  function testFuzz_preLeadingZero(uint8 _count, uint8 _at, uint256 _salt) public {
    _count = uint8(bound(_count, 1, 4));
    _at = uint8(bound(_at, 0, _count - 1));

    string memory list;
    uint256 salt = _salt;
    for(uint8 i; i < _count; i++) {
      string memory ident;
      if(i == _at) ident = _leadingZeroIdent(salt);
      else if(salt % 2 == 0) (ident, salt) = _numericIdent(salt / 2);
      else (ident, salt) = _alphaIdent(salt / 2);

      list = i == 0 ? ident : string.concat(list, ".", ident);
    }

    _reverts(string.concat("1.2.3-", list), NumericCannotHaveLeadingZeroes.selector);
  }

  function testFuzz_illegalChar(uint256 _pick, bool _inBuild) public {
    bytes1 c = _illegal(_pick);
    string memory raw = _inBuild
      ? string.concat("1.2.3+rc", string(bytes.concat(c)))
      : string.concat("1.2.3-rc", string(bytes.concat(c)));

    _reverts(raw, abi.encodeWithSelector(InvalidSemVerToken.selector, c));
  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Helpers
  //////////////////////////////////////////////////////////////////////////////

  function _expect(
    string memory _raw,
    uint8 _major,
    uint8 _minor,
    uint16 _patch,
    string memory _pre,
    string memory _build
  ) internal view {
    SemVer memory _v = harness.parse(_raw);

    assertEq(Major.unwrap(_v.major), _major, _raw);
    assertEq(Minor.unwrap(_v.minor), _minor, _raw);
    assertEq(Patch.unwrap(_v.patch), _patch, _raw);
    assertEq(_v.pre, _pre, _raw);
    assertEq(_v.build, _build, _raw);
  }

  function _reverts(string memory _raw, bytes4 _sel) internal {
    vm.expectRevert(_sel);
    harness.parse(_raw);
  }

  function _reverts(string memory _raw, bytes memory _data) internal {
    vm.expectRevert(_data);
    harness.parse(_raw);
  }

  function _identList(uint8 _count, uint256 _salt, bool _strict)
    internal
    pure
    returns (string memory list, uint256 salt)
  {
    salt = _salt;

    for(uint8 i; i < _count; i++) {
      string memory ident;
      if(salt % 2 == 0) {
        if(_strict) (ident, salt) = _numericIdent(salt / 2);
        else (ident, salt) = _digitsIdent(salt / 2);
      } else {
        (ident, salt) = _alphaIdent(salt / 2);
      }

      list = i == 0 ? ident : string.concat(list, ".", ident);
    }
  }

  function _numericIdent(uint256 _salt)
    internal
    pure
    returns (string memory ident, uint256 salt)
  {
    uint256 kind = _salt % 3;
    salt = _salt / 3;
    if(kind == 0) return ("0", salt);

    uint256 len = kind == 1 ? 1 : 2 + (salt % 3);
    if(kind != 1) salt /= 3;

    bytes memory raw = new bytes(len);
    raw[0] = bytes1(uint8(0x31 + (salt % 9)));
    salt /= 9;

    for(uint256 i = 1; i < len; i++) {
      raw[i] = bytes1(uint8(0x30 + (salt % 10)));
      salt /= 10;
    }

    ident = string(raw);
  }

  function _digitsIdent(uint256 _salt)
    internal
    pure
    returns (string memory ident, uint256 salt)
  {
    uint256 len = 1 + (_salt % 4);
    salt = _salt / 4;

    bytes memory raw = new bytes(len);
    for(uint256 i; i < len; i++) {
      raw[i] = bytes1(uint8(0x30 + (salt % 10)));
      salt /= 10;
    }

    ident = string(raw);
  }

  function _alphaIdent(uint256 _salt)
    internal
    pure
    returns (string memory ident, uint256 salt)
  {
    uint256 len = 1 + (_salt % 4);
    salt = _salt / 4;
    uint256 forced = salt % len;
    salt /= len;

    bytes memory raw = new bytes(len);
    for(uint256 i; i < len; i++) {
      if(i == forced || salt % 2 == 1) raw[i] = _nonDigit(salt);
      else raw[i] = bytes1(uint8(0x30 + ((salt / 2) % 10)));
      salt /= 53;
    }

    ident = string(raw);
  }

  function _nonDigit(uint256 _pick) internal pure returns (bytes1) {
    uint256 i = _pick % 53;
    if(i == 52) return bytes1("-");
    if(i < 26) return bytes1(uint8(0x61 + i));
    return bytes1(uint8(0x41 + (i - 26)));
  }

  function _leadingZeroIdent(uint256 _salt) internal pure returns (string memory ident) {
    uint256 len = 2 + (_salt % 3);
    uint256 salt = _salt / 3;

    bytes memory raw = new bytes(len);
    raw[0] = bytes1("0");
    for(uint256 i = 1; i < len; i++) {
      raw[i] = bytes1(uint8(0x30 + (salt % 10)));
      salt /= 10;
    }

    ident = string(raw);
  }

  function _illegal(uint256 _pick) internal pure returns (bytes1) {
    bytes memory bad = bytes(" _/!@#?~");
    return bad[_pick % bad.length];
  }

}
