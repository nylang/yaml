// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Shared YAML token kinds and plain scalar classification. */
module YamlLexical;
import "stdlib:stdlib.ny";

/**
 * @brief One scanner token. `line` / `column` are 1-based (token start).
 */
pub struct YamlToken {
  kind: int32;
  lexeme: string;
  line: int32;
  column: int32;
}


pub constexpr kYamlTokStreamEnd: int32 = 0;

pub constexpr kYamlTokPlain: int32 = 1;

pub constexpr kYamlTokStr: int32 = 2;

pub constexpr kYamlTokInt: int32 = 3;

pub constexpr kYamlTokBool: int32 = 4;

pub constexpr kYamlTokNull: int32 = 5;

pub constexpr kYamlTokColon: int32 = 6;

pub constexpr kYamlTokDash: int32 = 7;

pub constexpr kYamlTokLBrace: int32 = 8;

pub constexpr kYamlTokRBrace: int32 = 9;

pub constexpr kYamlTokLBracket: int32 = 10;

pub constexpr kYamlTokRBracket: int32 = 11;

pub constexpr kYamlTokComma: int32 = 12;

pub constexpr kYamlTokIndent: int32 = 13;

pub constexpr kYamlTokDedent: int32 = 14;

static method(YamlToken) IsDecimalInteger(s: string) -> bool {
  let n: int32 = s.length;
  if n <= 0 {
    return false;
  }

  var i: int32 = 0;
  if s.ByteAt(0) == 45 {
    if n == 1 {
      return false;
    }

    i = 1;
  }

  while i < n {
    if !YamlToken.IsDigit(s.ByteAt(i)) {
      return false;
    }

    i = i + 1;
  }

  return true;
}

/**
 * @brief Apply the scanner scalar rules before choosing a plain YAML spelling.
 * @returns The token kind assigned to this exact unquoted lexeme.
 */
pub static method(YamlToken) Classify(lexeme: string) -> int32 {
  if (lexeme == "~") {
    return kYamlTokNull;
  }

  if (lexeme == "null") {
    return kYamlTokNull;
  }

  if (lexeme == "Null") {
    return kYamlTokNull;
  }

  if (lexeme == "NULL") {
    return kYamlTokNull;
  }

  if (lexeme == "true") {
    return kYamlTokBool;
  }

  if (lexeme == "True") {
    return kYamlTokBool;
  }

  if (lexeme == "TRUE") {
    return kYamlTokBool;
  }

  if (lexeme == "false") {
    return kYamlTokBool;
  }

  if (lexeme == "False") {
    return kYamlTokBool;
  }

  if (lexeme == "FALSE") {
    return kYamlTokBool;
  }

  if YamlToken.IsDecimalInteger(lexeme) {
    return kYamlTokInt;
  }

  return kYamlTokPlain;
}

/**
 * @brief Recognize ASCII decimal digits used by YAML scalar classification.
 * @returns True for bytes 0 through 9 in ASCII spelling.
 */
pub static method(YamlToken) IsDigit(b: int32) -> bool {
  if b < 48 {
    return false;
  }

  return b <= 57;
}
