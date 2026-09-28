// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

import {IERC165} from "./eip/IERC165.sol";
import {IkhaaliSemVerErrorsV1} from "./util/IkhaaliSemVerErrorsV1.sol";

import {SemVer} from "./util/khaaliSemVerV2Types.sol";

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
interface IkhaaliSemVerV2 is IERC165, IkhaaliSemVerErrorsV1 {

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
  ///// External Functions
  //////////////////////////////////////////////////////////////////////////////

  /// @notice Primary function to get the contract version
  /// @return The contract version as a tuple
  function version() external view returns (SemVer memory);

  /// @notice Primary function to get the contract version
  /// @return The semver core as a string
  function pretty() external view returns (string memory);

  /// @notice Primary function to get the contract version
  /// @return The full semver as a string
  function semver() external view returns (string memory);

  ///
  /// @param raw Raw SemVer string
  /// @return isGreater Whether given string is greater than contract version
  function compare(string memory raw) external returns (bool isGreater);

  ///
  /// @param raw Raw SemVer string in bytes
  /// @return isGreater Whether given string is greater than contract version
  function compare(bytes memory raw) external returns (bool isGreater);

  //////////////////////////////////////////////////////////////////////////////
  ///// Admin Functionality
  //////////////////////////////////////////////////////////////////////////////

  function deprecateContract(address newAddress) external;

  function abandonContract() external;


  //////////////////////////////////////////////////////////////////////////////
  ///// Contract Upkeep
  //////////////////////////////////////////////////////////////////////////////

  function updateAdmin(address newAdmin) external;
}
