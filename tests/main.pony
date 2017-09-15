use "files"
use "peg"
use "ponytest"
use ".."

actor Main is TestList
  new create(env: Env) => PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestParseVersion)
    test(_TestParseDate)
    test(_TestParseEntries)
    test(_TestParseChangelog)
    test(_TestSingleRelease)

class ParseTest
  let _h: TestHelper
  let _parser: Parser

  new create(h: TestHelper, parser: Parser) =>
    (_h, _parser) = (h, parser)

  fun run(tests: Array[(String, String)]) =>
    for (source, expected) in tests.values() do
      _h.log("test: " + source)
      let source' = Source.from_string(source)
      match recover val _parser.parse(source') end
      | (_, let r: (AST | Token | NotPresent)) =>
        let result = recover val Printer(r) end
        _h.assert_eq[String](expected, result)
      | (let offset: USize, let r: Parser val) =>
        let e = recover val SyntaxError(source', offset, r) end
        _Logv(_h, PegFormatError.console(e))
        _h.assert_eq[String](expected, "")
      | (_, Skipped) => _h.log("skipped")
      | (_, Lex) => _h.log("lex")
      end
    end

class iso _TestParseVersion is UnitTest
  fun name(): String => "parse version"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.version()).run(
      [ ("0.0.0", "(Version 0.0.0)\n")
        ("1.23.9", "(Version 1.23.9)\n")
        ("0..0", "")
        (".0.0", "")
        ("0..", "")
        ("0", "")
      ])

class iso _TestParseDate is UnitTest
  fun name(): String => "parse date"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.date()).run(
      [ ("2017-04-07", "(Date 2017-04-07)\n")
        ("0000-00-00", "(Date 0000-00-00)\n")
        ("0000-00-0", "")
        ("0000-0-00", "")
        ("000-00-00", "")
        ("00-0000-00", "")
      ])

class iso _TestParseEntries is UnitTest
  fun name(): String => "parse entries"

  fun apply(h: TestHelper) =>
    ParseTest(h, ChangelogParser.entries()).run(
      [ ("32-bit ARM port.", "")
        ("- 32-bit ARM port.", "(Entries - 32-bit ARM port.)\n")
        ("- abc\n  - def\n\n", "(Entries - abc\n  - def)\n")
        ( """
          - abc
            - def
              - ghi
            - jkl
          """,
          "(Entries - abc\n  - def\n    - ghi\n  - jkl)\n" )
        ( "- @fowles: handle regex empty match.",
          "(Entries - @fowles: handle regex empty match.)\n" )
        ( "- Upgrade to LLVM 3.9.1 ([PR #1498](https://github.com/ponylang/ponyc/pull/1498))",
          "(Entries - Upgrade to LLVM 3.9.1 ([PR #1498](https://github.com/ponylang/ponyc/pull/1498)))\n" )
      ])

class iso _TestParseChangelog is UnitTest
  fun name(): String => "parse CHANGELOG"

  fun apply(h: TestHelper) ? =>
    let p = recover val ChangelogParser() end
    let testfile = "CHANGELOG.md"

    with file = OpenFile(
      FilePath(h.env.root as AmbientAuth, testfile)?) as File
    do
      let source: String = file.read_string(file.size())
      let source' = Source.from_string(source)
      match recover val p.parse(source') end
      | (let n: USize, let r: (AST | Token | NotPresent)) =>
        match r
        | let ast: AST =>
          let changelog = Changelog(ast)?
          h.assert_eq[String](source, changelog.string())
        else
          h.log(recover val Printer(r) end)
          h.fail()
        end
      | (let offset: USize, let r: Parser val) =>
        let e = recover val SyntaxError(source', offset, r) end
        _Logv(h, PegFormatError.console(e))
        h.fail()
      end
    else
      h.fail()
    end

class iso _TestSingleRelease is UnitTest
  fun name(): String => "single release"

  fun apply(h: TestHelper) ? =>
    let input =
      """
      # Change Log

      All notable changes to the Pony compiler and standard library will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

      ## [unreleased] - unreleased

      ### Fixed

      - Fix invalid separator in PONYPATH for Windows. ([PR #32](https://github.com/ponylang/pony-stable/pull/32))

      ### Added



      ### Changed


      """

    let expected =
      """
      # Change Log

      All notable changes to the Pony compiler and standard library will be documented in this file. This project adheres to [Semantic Versioning](http://semver.org/) and [Keep a CHANGELOG](http://keepachangelog.com/).

      ## [unreleased] - unreleased

      ### Fixed

      - Fix invalid separator in PONYPATH for Windows. ([PR #32](https://github.com/ponylang/pony-stable/pull/32))

      ### Added



      ### Changed



      """

    let source = Source.from_string(input)
    let p = recover val ChangelogParser() end
    match recover val p.parse(source) end
    | (let n: USize, let r: (AST | Token | NotPresent)) =>
      match r
      | let ast: AST =>
        let changelog = Changelog(ast)?
        h.log(changelog.string())
        h.assert_eq[String](expected, changelog.string())
      else
        h.log(recover val Printer(r) end)
        h.fail()
      end
    | (let offset: USize, let r: Parser val) =>
      let e = recover val SyntaxError(source, offset, r) end
      _Logv(h, PegFormatError.console(e))
      h.fail()
    end

primitive _Logv
  fun apply(h: TestHelper, bsi: ByteSeqIter) =>
    let str = recover String end
    for bs in bsi.values() do
      str.append(
        match bs
        | let s: String => s
        | let a: Array[U8] val => String.from_array(a)
        end)
    end
    h.log(consume str)
