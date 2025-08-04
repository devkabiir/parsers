# Parser Combinators for Dart

Writing parsers can but fun, reasonable, fast and readable.

## Quick Start

```dart
import 'package:parsers/parsers.dart';
import 'dart:math';

// grammar

final number = digit.many1       ^ digits2int
             | string('none')    ^ none
             | string('answer')  ^ answer;

final comma = char(',') < spaces;

final numbers = number.sepBy(comma) < eof;

// actions

digits2int(digits) => parseInt(Strings.concatAll(digits));
none(_) => null;
answer(_) => 42;

// parsing

main() {
  print(numbers.parse('0,1, none, 3,answer'));
  // [0, 1, null, 3, 42]

  print(numbers.parse('0,1, boom, 3,answer'));
  // line 1, character 6: expected digit, 'none' or 'answer', got 'b'.
}
```

## Building a C-like language parser
This library provides `LanguageParsers` abstraction which makes it very easy to implement
ASTs from source code.
```dart
// We extend LanguageParsers to benefit from all the C-like language-specific
// comment-aware, reserved names-aware, literals combinators.

class MiniLang extends LanguageParsers {
  MiniLang() : super(reservedNames: ['var', 'if', 'else', 'true', 'false']);

  get start => stmts().between(spaces, eof);

  stmts() => stmt().endBy(semi);
  stmt() => declStmt() | assignStmt() | ifStmt();
  // In a real parser, we would build AST nodes, but here we turn sequences
  // into lists via the list getter for simplicity.
  declStmt() => (reserved['var'] + identifier + symbol('=') + expr()).list;
  assignStmt() => (identifier + symbol('=') + expr()).list;
  ifStmt() => (reserved['if'] +
          parens(expr()) +
          braces(rec(stmts)) +
          reserved['else'] +
          braces(rec(stmts)))
      .list;

  expr() => disj().sepBy1(symbol('||'));
  disj() => comp().sepBy1(symbol('&&'));
  comp() => arith().sepBy1(symbol('<') | symbol('>'));
  arith() => term().sepBy1(symbol('+') | symbol('-'));
  term() => atom().withPosition.sepBy1(symbol('*') | symbol('/'));

  atom() =>
      floatLiteral |
      intLiteral |
      stringLiteral |
      reserved['true'] |
      reserved['false'] |
      identifier |
      parens(rec(expr));
}
```
The following example source code for a mini C-like language can be parsed easily.
```js
  var i = 14;     // "vari = 14" is a parse error
  var j = 2.3e4;  // using var instead of j is a parse error
  /* 
     multi-line comments are 
     supported and tunable
  */
  if (i < j + 2 * 3 || true) {
    i = "foo\t";
  } else {
    j = false;
  };  // we need a semicolon here because of endBy
```

```dart
void main() {
  print(MiniLang().start.parse(test));
}
```

## Building a langauge parser that produces AST
Below is an example parser for datacore language in less than 150 LOC.

See the full example in
[`mini_ast.dart`](https://github.com/devkabiir/parsers/tree/master/example/mini_ast.dart).

```dart
// <AST node definitions trimmed for brevity>
class DataCoreParser extends LanguageParsers {
  DataCoreParser()
      : super(
            reservedNames: reservedNames,
            // tells LanguageParsers to not handle comments
            commentStart: "",
            commentEnd: "",
            commentLine: "");

  Parser get docString => lexeme(_docString).many;

  Parser get _docString =>
      everythingBetween(string('//'), string('\n')) |
      everythingBetween(string('/*'), string('*/')) |
      everythingBetween(string('/**'), string('*/'));

  Parser get namespaceDeclaration =>
      docString +
          reserved["namespace"] +
          identifier +
          braces(namespaceBody) +
          semi ^
      namespaceDeclarationMapping;

  Parser get namespaceBody => body.many;

  Parser get body => interfaceDeclaration | dictionaryDeclaration;

  Parser get interfaceDeclaration =>
      docString +
          reserved["interface"] +
          identifier +
          braces(interfaceBody) +
          semi ^
      interfaceDeclarationMapping;

  Parser get interfaceBody => method.many;

  Parser get method => regularMethod | voidMethod;

  Parser typeAppl() =>
      identifier + angles(rec(typeAppl).sepBy(comma)).orElse([]) ^
      (c, args) => TypeAppl(c, args);

  Parser get parameter =>
      (typeAppl() % 'type') + (identifier % 'parameter') ^
      (t, p) => Parameter(t, p);

  Parser get regularMethod =>
      docString +
          typeAppl() +
          identifier +
          parens(parameter.sepBy(comma)) +
          semi ^
      methodDeclarationRegularMapping;

  Parser get voidMethod =>
      docString +
          reserved['void'] +
          identifier +
          parens(parameter.sepBy(comma)) +
          semi ^
      methodDeclarationReservedMapping;

  Parser get dictionaryDeclaration =>
      docString +
          reserved["dictionary"] +
          identifier +
          braces(dictionaryBody) +
          semi ^
      dictionaryDeclarationMapping;

  Parser get dictionaryBody => field.many;

  Parser get field =>
      docString + typeAppl() + identifier + semi ^ fieldDeclarationMapping;
}
```

The above parser will produce an AST that can be easily converted back to exact source
code as example:
```dart

final test = """
// Data core processor package
// Second comment line

namespace datacore {
  // Defined interface of the processor
  interface DataProc {
    // Loads data for the processor,
    // pass the size of the loaded data
    bool loadData(array data, int size);

    // Executes the processor
    void run();

    /* Returns the result of the processor */
    DataProcResult result();
  };

  /**
   * A data type for the processor result
   * Multi line comment
   * With information. 
   */
  dictionary DataProcResult {
    // Time spent processing
    double timeSpent;

    // Value calculated from processing
    int value;
  };
};
""";

void main() {
  DataCoreParser dataCoreParser = DataCoreParser();
  NamespaceDeclaration namespaceDeclaration =
      dataCoreParser.namespaceDeclaration.between(spaces, eof).parse(test);
  print(namespaceDeclaration);
}

```


## Advanced Examples
See the
[example](https://github.com/devkabiir/parsers/tree/master/example)
directory for advanced usage.

## Limitations
For the most part, `dynamic` can be used to write readable parser code while loosing some
  static type safety. However this is not a flaw in design or implementation, parsers
  operate on untrusted user input which cannot be realistically type checked at static
  time without relying on extensive meta-programming and language features.  

This library
  aims to make writing parsers easier and readable. Readable code is far better and easier
  to understand, reason about, and debug than code with extensive type safety and
  meta-programming primitives.

Due to the following growth of Dart's language semantics and features, it has become
harder to make a parser generator that can be written with simple generic free code and
still provide type safety.
- Dart 2.0 and beyond has what they call "sound type system", while it sounds fancy, it is
  a shift to static type safety.
quite limited in meta-programming and static type inference.
- Dart 2.12 introduced optional null-safety
- Dart 3.0 and beyond null-safety is built-in and cannot be turned off.
- Limited type inference capabilities when chaining series of parser, hence the need for
  [`ParserAccumulator2`](https://github.com/devkabiir/parsers/tree/master/lib/src/accumulators.dart)
  and friends
- No support for generic types on operators such as `|`, `&`, etc. This severely limits the
  syntactic sugar that can be implemented.


## About
This is a fork of polux/parsers with Dart 2.0 support and various test/bug fixes.
Originally this library was heavily inspired by
[Parsec](http://hackage.haskell.org/package/parsec), but differs on some
points. In particular, the `|` operator has a sane backtracking semantics, as
in [Polyparse](http://code.haskell.org/~malcolm/polyparse/docs/). As a
consequence it is slower but also easier to use. I've also introduced some
syntax for transforming parsing results that doesn't require any knowledge of
monads or applicative functors and features uncurried functions, which are
nicer-looking than curried ones in Dart.
