// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;

interface IkhaaliSemVerErrorsV1 {

  //////////////////////////////////////////////////////////////////////////////
  ///// Parser Errors
  //////////////////////////////////////////////////////////////////////////////

  error VersionTooLong();
  error VersionCannotBeEmpty();
  error InvalidSemVerToken(bytes1 token);

  error VersionCoreTooHigh(uint max, uint seen);
  error InvalidCoreSeparator(bytes1 token);
  error VersionCoreIsIncomplete();
  error VersionCoreCannotHaveNonDigit();

  error IdentifierCannotBeEmpty();
  error NumericCannotHaveLeadingZeroes();
  error DigitContainsNonDigit(bytes1 char);

  error InvalidInternalCall();

  //////////////////////////////////////////////////////////////////////////////
  ///// Versioning Errors
  //////////////////////////////////////////////////////////////////////////////


  error FunctionUnimplemented(bytes4 selector);
  error FunctionDeprecated(bytes4 selector);

  //////////////////////////////////////////////////////////////////////////////
  ///// Functionality Errors
  //////////////////////////////////////////////////////////////////////////////

  error PendingAdminMustAcceptBeforeCalling();
  error PendingAdminMustAcceptOrDecline(address pending);
  error AdminFunctionCalledByNonAdmin(address caller, address admin);

}
