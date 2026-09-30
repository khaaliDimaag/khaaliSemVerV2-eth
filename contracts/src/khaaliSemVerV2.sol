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

  SemVer public version;
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
  ///// Getters
  //////////////////////////////////////////////////////////////////////////////

  /// @inheritdoc IkhaaliSemVerV2
  function pretty() public view returns (string memory) {
    return string.concat(
      _uint2str(Major.unwrap(version.major)),
      ".",
      _uint2str(Minor.unwrap(version.minor)),
      ".",
      _uint2str(Patch.unwrap(version.patch))
    );
  }

  /// @inheritdoc IkhaaliSemVerV2
  function semver() public view returns (string memory) {
    string memory pre; string memory build;
    if(bytes(version.pre).length != 0)
      pre = string.concat("-", version.pre);
    if(bytes(version.build).length != 0)
      build = string.concat("+", version.build);
    return string.concat(pretty(), pre, build);
  }

  /// @inheritdoc IkhaaliSemVerV2
  function prerelease() public view returns (string memory) {
    return version.pre;
  }

  /// @inheritdoc IkhaaliSemVerV2
  function revision() public view returns (string memory) {
    return version.build;
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// External Functions
  //////////////////////////////////////////////////////////////////////////////

  /// @inheritdoc IkhaaliSemVerV2
  function compare(string memory _raw) public view returns (bool isGreater) {
    return compare(bytes(_raw));
  }

  /// @inheritdoc IkhaaliSemVerV2
  function compare(bytes memory _raw) public view returns (bool isGreater) {

    SemVer memory _v = parseVersion(_raw);

    // major, minor, and patch versions are always compared numerically
    if(Major.unwrap(_v.major) != Major.unwrap(version.major))
      return Major.unwrap(_v.major) > Major.unwrap(version.major);
    else if(Minor.unwrap(_v.minor) != Minor.unwrap(version.minor))
      return Minor.unwrap(_v.minor) > Minor.unwrap(version.minor);
    else if(Patch.unwrap(_v.patch) != Patch.unwrap(version.patch))
      return Patch.unwrap(_v.patch) > Patch.unwrap(version.patch);

    // compare pre-release tags

    bytes memory _preArgBytes = bytes(_v.pre);
    bytes memory _preStateBytes = bytes(version.pre);


    // a pre-release version has lower precedence than a normal version
    if(_preArgBytes.length == 0 && _preStateBytes.length == 0) return false;
    else if(_preStateBytes.length == 0) return false;
    else if(_preArgBytes.length == 0) return true;

    uint _idxArg; uint _idxState;

    while(true) {
      bool _argIsDone = _idxArg >= _preArgBytes.length;
      bool _stateIsDone = _idxState >= _preStateBytes.length;

      // 4. A larger set of pre-release fields has higher precedence
      if(_argIsDone && _stateIsDone) return false;
      else if(_argIsDone) return false;
      else if(_stateIsDone) return true;

      (uint _argEnd, bool _isArgNumeric) =
        _walkIdentifier(_preArgBytes, _idxArg);
      (uint _stateEnd, bool _isStateNumeric) =
        _walkIdentifier(_preStateBytes, _idxState);

      uint _argLen = _argEnd - _idxArg;
      uint _stateLen = _stateEnd - _idxState;

      // 3. Numeric identifiers have lower precedence than non-numeric.
      if(_isArgNumeric && !_isStateNumeric) return false;
      else if(!_isArgNumeric && _isStateNumeric) return true;

      // 2. Identifiers with nonDigits are compared in ASCII sort order.
      else if(!_isArgNumeric && !_isStateNumeric) {
        uint _smaller = _argLen < _stateLen? _argLen : _stateLen;

        for(uint _i; _i < _smaller; _i++) {
          bytes1 _argChar = _preArgBytes[_idxArg + _i];
          bytes1 _stateChar = _preStateBytes[_idxState + _i];
          if(_argChar != _stateChar) return _argChar > _stateChar;
        }

        if(_argLen != _stateLen) return _argLen > _stateLen;
      }

      // 1. Identifiers consisting of only digits are compared numerically.
      else {
        if(_argLen != _stateLen) return _argLen > _stateLen;

        for(uint _i; _i < _argLen; _i++) {
          bytes1 _argChar = _preArgBytes[_idxArg + _i];
          bytes1 _stateChar = _preStateBytes[_idxState + _i];
          if(_argChar != _stateChar) return _argChar > _stateChar;
        }
      }

      // Equal identifier pair, lets step past the '.' (or beyond length)
      _idxArg = _argEnd + 1;
      _idxState = _stateEnd + 1;
    }

  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Main Functionality
  //////////////////////////////////////////////////////////////////////////////

  function deprecate() external onlyAdmin {

  }

  //////////////////////////////////////////////////////////////////////////////
  ///// Internal Functions
  //////////////////////////////////////////////////////////////////////////////

  function _uint2str(uint n) internal pure returns (string memory) {

    if(n == 0) return "0";

    uint temp = n;
    uint digits;

    while(temp != 0) {
      digits++;
      temp /= 10;
    }

    bytes memory buffer = new bytes(digits);
    while(n != 0) {
      buffer[--digits] = bytes1(uint8(0x30 + (n%10)));
      n /= 10;
    }

    return string(buffer);
  }

  function _walkIdentifier(bytes memory dotSeparated, uint idx)
    private
    pure
    returns(uint end, bool isNumeric)
  {

    bool sawNonDigit;

    while(idx < dotSeparated.length) {
      SemVerToken _t = _whichToken(dotSeparated[idx]);

      if(_t == SemVerToken.DOT) break;

      if(_t != SemVerToken.ZERO && _t != SemVerToken.POSITIVE)
        sawNonDigit = true;

      idx++;
    }

    return (idx, !sawNonDigit);
  }


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
