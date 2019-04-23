// Copyright (c) 2012, Google Inc. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// Author: Paul Brauner (polux@google.com)

library example;

import 'package:parsers/parsers.dart';

// Same example as example.dart, with the additional use of chainl1 which
// helps handling infix operators with the same precedence.

class Arith {
  digits2int(digits) => int.parse(digits.join());

  lexeme(parser) => parser < spaces;
  token(str) => lexeme(string(str));
  parens(parser) => parser.between(token('('), token(')'));

  get start => expr() < eof;

  get comma => token(',');
  get times => token('*');
  get div => token('~/');
  get plus => token('+');
  get minus => token('-');
  get number => lexeme(digit.many1) ^ digits2int;

  expr() => rec(term).chainl1(addop);
  term() => rec(atom).chainl1(mulop);
  atom() => number | parens(rec(expr));

  get addop =>
      (plus > success((x, y) => x + y)) | (minus > success((x, y) => x - y));

  get mulop =>
      (times > success((x, y) => x * y)) | (div > success((x, y) => x ~/ y));
}

main() {
  final s = "1 * 2 ~/ 2 + 3 * (4 + 5 - 1)";
  print(Arith().start.parse(s)); // prints 25
}
