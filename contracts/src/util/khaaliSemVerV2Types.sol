// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.20;


////////////////////////////////////////////////////////////////////////////////

type Major is uint8;
type Minor is uint8;
type Patch is uint16;

struct SemVer {
  Major major;
  Minor minor;
  Patch patch;
  string pre;
  string build;
}


////////////////////////////////////////////////////////////////////////////////

enum SemVerToken {
  INVALID,    // default is 0
  PLUS,       // 0x2B [43]
  DASH,       // 0x2D [45]
  DOT,        // 0x2E [46]
  ZERO,       // 0x30 [48]
  POSITIVE,   // 0x31 - 0x39 [49 - 57]
  ALPHA_LG,   // 0x41 - 0x5A [65 - 90]
  ALPHA_SM    // 0x61 - 0x7A [97 - 122]
}


////////////////////////////////////////////////////////////////////////////////
