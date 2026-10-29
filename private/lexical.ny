// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Shared YAML token kinds and plain scalar classification. */
module YamlLexical;
import "stdlib:stdlib.ny";

pub static kYamlTokStreamEnd: int32 = 0;

pub static kYamlTokPlain: int32 = 1;

pub static kYamlTokStr: int32 = 2;

pub static kYamlTokInt: int32 = 3;

pub static kYamlTokBool: int32 = 4;

pub static kYamlTokNull: int32 = 5;

pub static kYamlTokColon: int32 = 6;

pub static kYamlTokDash: int32 = 7;

pub static kYamlTokLBrace: int32 = 8;

pub static kYamlTokRBrace: int32 = 9;

pub static kYamlTokLBracket: int32 = 10;

pub static kYamlTokRBracket: int32 = 11;

pub static kYamlTokComma: int32 = 12;

pub static kYamlTokIndent: int32 = 13;

pub static kYamlTokDedent: int32 = 14;

func yaml_is_decimal_int(s: string) -> bool {
  let n: int32 = s.length;
  if n <= 0 {
    return false;
  }

  var i: int32 = 0;
  if YamlByteAt(s, 0) == 45 {
    if n == 1 {
      return false;
    }

    i = 1;
  }

  while i < n {
    if !YamlIsDigit(YamlByteAt(s, i)) {
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
pub func YamlClassifyPlain(lexeme: string) -> int32 {
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

  if yaml_is_decimal_int(lexeme) {
    return kYamlTokInt;
  }

  return kYamlTokPlain;
}

/**
 * @brief Read a YAML lexical source byte with an explicit bounds sentinel.
 * @returns A widened byte, or -1 outside the source range.
 */
pub func YamlByteAt(s: string, i: int32) -> int32 {
  if i < 0 {
    return -1;
  }

  if i >= s.length {
    return -1;
  }

  return (s[i] as int32) & 255;
}

/**
 * @brief Recognize ASCII decimal digits used by YAML scalar classification.
 * @returns True for bytes 0 through 9 in ASCII spelling.
 */
pub func YamlIsDigit(b: int32) -> bool {
  if b < 48 {
    return false;
  }

  return b <= 57;
}
