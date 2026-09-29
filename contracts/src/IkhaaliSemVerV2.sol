// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "./eip/IERC165.sol";

import {IkhaaliAdmin} from "./util/IkhaaliAdmin.sol";
import {IkhaaliSemVerErrorsV1} from "./util/IkhaaliSemVerErrorsV1.sol";

import {SemVer} from "./util/khaaliSemVerV2Types.sol";
import {Major, Minor, Patch} from "./util/khaaliSemVerV2Types.sol";

enum FunctionDeprecation {
  UNIMPLEMENTED,
  ACTIVE,
  SCHEDULED,
  REMOVED
}

struct FunctionStatus {
  SemVer introduced;
  SemVer deprecated;
  SemVer removed;
  FunctionDeprecation status;
}

/// @title IkhaaliSemVerV2
/// @notice Explicit Semantic Versioning for contracts
interface IkhaaliSemVerV2 is IERC165, IkhaaliAdmin, IkhaaliSemVerErrorsV1 {

  enum UpdateKind {
    UNCHANGED, BREAKING, FEATURE, FIX
  }


  //////////////////////////////////////////////////////////////////////////////
  ///// Events
  //////////////////////////////////////////////////////////////////////////////

  event ContractDeprecated(
    address indexed newAddress,
    UpdateKind indexed kind,
    SemVer oldVersion,
    SemVer newVersion
  );

  //////////////////////////////////////////////////////////////////////////////
  ///// Getters
  //////////////////////////////////////////////////////////////////////////////

  /// @notice Primary function to get the contract version struct
  /// @return The contract version as a tuple
  function version() external view
    returns (Major, Minor, Patch, string memory, string memory);

  /// @notice Primary function to get the core contract version
  /// @return The semantic version core as a string
  function pretty() external view returns (string memory);

  /// @notice Primary function to get the full contract version
  /// @return The full semantic version as a string
  function semver() external view returns (string memory);

  /// @notice Get the pre-release tag if it exists
  /// @return The pre-release tag as a string, or empty string
  function prerelease() external view returns (string memory);

  /// @notice Get the build tag if it exists
  /// @return The build tag as a string, or empty string
  function revision() external view returns (string memory);

  //////////////////////////////////////////////////////////////////////////////
  ///// External Functions
  //////////////////////////////////////////////////////////////////////////////

  ///
  /// @param raw Raw SemVer string
  /// @return isGreater Whether given string is greater than contract version
  function compare(string memory raw) external returns (bool isGreater);

  ///
  /// @param raw Raw SemVer string in bytes
  /// @return isGreater Whether given string is greater than contract version
  function compare(bytes memory raw) external returns (bool isGreater);

  //////////////////////////////////////////////////////////////////////////////
  ///// Main Functionality
  //////////////////////////////////////////////////////////////////////////////

  function deprecateContract(address newAddress) external;

  function abandonContract() external;

}
