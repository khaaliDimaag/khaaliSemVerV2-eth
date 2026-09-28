// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IkhaaliSemVerErrorsV1} from "./IkhaaliSemVerErrorsV1.sol";

import {SemVerToken, SemVer} from "./khaaliSemVerV2Types.sol";
import {Major, Minor, Patch} from "./khaaliSemVerV2Types.sol";

/// @dev Marked `abstract` since this is not meant to be standalone
abstract contract khaaliSemVerParserV1 is IkhaaliSemVerErrorsV1 {

  function parseVersion(bytes memory _raw)
    internal
    pure
    returns (SemVer memory v)
  {
    if(_raw.length == 0) revert VersionCannotBeEmpty();

    uint _idx = 0;

    (v.major, v.minor, v.patch, _idx) = parseCore(_raw, _idx);

    // check for completion
    if(_idx == _raw.length) return v;


    if(_whichToken(_raw[_idx]) == SemVerToken.DASH) {
      (v.pre, _idx) = parsePre(_raw, _idx);

      // check for completion
      if(_idx == _raw.length) return v;
    }

    if(_whichToken(_raw[_idx]) == SemVerToken.PLUS) {
      (v.build, _idx) = parseBuild(_raw, _idx);

      // check for completion
      if(_idx == _raw.length) return v;
    }

    revert VersionTooLong();
  }

  function parseCore(bytes memory _raw, uint _idx)
    internal
    pure
    returns (Major major, Minor minor, Patch patch, uint idx)
  {
    uint _n; uint _end;

    // major, then a required '.'
    _end = _parseIdentifier(_raw, _idx, true, true);
    _n = _bytesToUint(_slice(_raw, _idx, _end));
    if(_n > type(uint8).max) revert VersionCoreTooHigh(type(uint8).max, _n);
    major = Major.wrap(uint8(_n));

    // verify core continuation and legal separation
    if(_end == _raw.length) revert VersionCoreIsIncomplete();
    if(_whichToken(_raw[_end]) != SemVerToken.DOT)
      revert InvalidCoreSeparator(_raw[_end]);

    // move index past separating '.'
    _idx = _end + 1;

    // minor, then a required '.'
    _end = _parseIdentifier(_raw, _idx, true, true);
    _n = _bytesToUint(_slice(_raw, _idx, _end));
    if(_n > type(uint8).max) revert VersionCoreTooHigh(type(uint8).max, _n);
    minor = Minor.wrap(uint8(_n));

    // verify core continuation and legal separation
    if(_end == _raw.length) revert VersionCoreIsIncomplete();
    if(_whichToken(_raw[_end]) != SemVerToken.DOT)
      revert InvalidCoreSeparator(_raw[_end]);

    // move index past separating '.'
    _idx = _end + 1;

    // patch, may end at EOF, '-', or '+'
    _end = _parseIdentifier(_raw, _idx, true, true);
    _n = _bytesToUint(_slice(_raw, _idx, _end));
    if(_n > type(uint16).max) revert VersionCoreTooHigh(type(uint16).max, _n);
    patch = Patch.wrap(uint16(_n));

    // version is more than core
    if(_end != _raw.length) {
      SemVerToken _t = _whichToken(_raw[_end]);
      if(_t != SemVerToken.DASH && _t != SemVerToken.PLUS)
        revert VersionCoreCannotHaveNonDigit();
    }

    idx = _end;
  }

  ///
  /// @param _raw Version string to be process
  /// @param _idx Index of starting token (must point to '-')
  /// @return pre
  /// @return idx
  function parsePre(bytes memory _raw, uint _idx)
    internal
    pure
    returns (string memory pre, uint idx)
  {
    require(_whichToken(_raw[_idx]) == SemVerToken.DASH, InvalidInternalCall());
    idx = _parseDotSeparated(_raw, _idx+1, true);
    pre = string(_slice(_raw, _idx+1, idx));
  }

  ///
  /// @param _raw Version string to be process
  /// @param _idx Index of starting token (must point to '+')
  /// @return build
  /// @return idx
  function parseBuild(bytes memory _raw, uint _idx)
    internal
    pure
    returns (string memory build, uint idx)
  {
    require(_whichToken(_raw[_idx]) == SemVerToken.PLUS, InvalidInternalCall());
    idx = _parseDotSeparated(_raw, _idx+1, false);
    build = string(_slice(_raw, _idx+1, idx));
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Private Helpers
  //////////////////////////////////////////////////////////////////////////////


  function _parseDotSeparated(bytes memory _raw, uint _idx, bool _strictNumeric)
    internal
    pure
    returns (uint idx)
  {
    if(_idx == _raw.length) revert IdentifierCannotBeEmpty();

    while(true) {
      idx = _parseIdentifier(_raw, _idx, false, _strictNumeric);

      // stopping conditions
      if(idx == _raw.length) return idx;
      if(_whichToken(_raw[idx]) != SemVerToken.DOT) return idx;

      // check for trailing dot
      if(idx+1 == _raw.length) revert IdentifierCannotBeEmpty();

      // move index past separating '.'
      _idx = idx + 1;
    }
  }

  function _parseIdentifier(
    bytes memory _raw,
    uint _idx,
    bool _isCore,
    bool _strictNumeric
  )
    internal
    pure
    returns (uint idx)
  {
    idx = _idx;
    bool _sawNonDigit;

    while(idx != _raw.length) {
      SemVerToken _t = _whichToken(_raw[idx]);

      /// @dev there must be a smarter way to check these conditions

      if(_isCore) {
        // break on non-digit in core (ie, major or minor or patch)
        if(_t != SemVerToken.ZERO && _t != SemVerToken.POSITIVE) break;
      } else {
        // break on '.' or '+' for non-core (ie, pre or build)
        if(_t == SemVerToken.DOT || _t == SemVerToken.PLUS) break;
      }

      // keep track of non-digit scan
      if(_t != SemVerToken.ZERO && _t != SemVerToken.POSITIVE)
        _sawNonDigit = true;

      idx++;
    }

    // check if loop ran
    if(idx == _idx) revert IdentifierCannotBeEmpty();

    // leading zeroes check (for digits only in core and pre-release)
    if(_strictNumeric && !_sawNonDigit && _raw[_idx] == 0x30 && idx > _idx+1)
      revert NumericCannotHaveLeadingZeroes();
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Utility Functions
  //////////////////////////////////////////////////////////////////////////////


  /// @dev reverts on anything outside [0-9A-Za-z.+-]
  function _whichToken(bytes1 _c) private pure returns (SemVerToken) {

    if(_c == 0x2B)
      return SemVerToken.PLUS;
    else if (_c == 0x2D)
      return SemVerToken.DASH;
    else if (_c == 0x2E)
      return SemVerToken.DOT;
    else if(_c == 0x30)
      return SemVerToken.ZERO;
    else if(_c >= 0x31 && _c <= 0x39)
      return SemVerToken.POSITIVE;
    else if(_c >= 0x41 && _c <= 0x5A)
      return SemVerToken.ALPHA_LG;
    else if(_c >= 0x61 && _c <= 0x7A)
      return SemVerToken.ALPHA_SM;
    else revert InvalidSemVerToken(_c);

  }

  function _slice(bytes memory _raw, uint _start, uint _end)
    private
    pure
    returns (bytes memory sliced)
  {
    sliced = new bytes(_end - _start);
    for(uint i; i < sliced.length; i++)
      sliced[i] = _raw[_start + i];
  }

  function _bytesToUint(bytes memory _sliced)
    private
    pure
    returns (uint num)
  {
    for(uint i=0; i < _sliced.length; i++) {
      uint8 n = uint8(_sliced[i]);
      if(n < 0x30 || n > 0x39) revert DigitContainsNonDigit(bytes1(n));
      num = num*10 + (n-0x30);
    }
  }

}
