import gleeunit
import gleeunit/should
import argenie.{
  Argenie, Custom, IntArg, InvalidStringValue, MandatoryMissing, NotInRange,
  ParseError, ParseErrors, Validation,
}
import gleam/option.{None, Option, Some}
import gleam/string
import gleam/map.{Map}

pub fn main() {
  gleeunit.main()
}

pub type Numbers {
  One
  Two
  Three
}

pub type MyArg {
  Hello(value: String)
  Test(value: Int)
  Number(value: Numbers)
  NoDefault(value: Option(String))
  Mandatory(value: String)
  Verbose(value: Bool)
  Big(value: Int)
  Ar(value: String)
}

type Flags {
  Flags(
    hello: String,
    my_int: String,
    number: String,
    no_default: String,
    mandatory: String,
    verbose: String,
    big: String,
    ar: String,
  )
}

const flags = Flags(
  "hello",
  "my_int",
  "number",
  "no_default",
  "mandatory",
  "verbose",
  "big",
  "ar",
)

fn setup_args() {
  argenie.new()
  |> argenie.add_string_argument(
    flags.hello,
    Hello("default"),
    None,
    fn(new_value: String) { Hello(new_value) },
  )
  |> argenie.add_int_argument(
    flags.my_int,
    Test(42),
    argenie.range(40, 45),
    fn(new_value: Int) { Test(new_value) },
  )
  |> argenie.add_string_argument(
    flags.number,
    Number(One),
    argenie.one_of(["one", "two", "three"]),
    fn(new_value: String) {
      case new_value {
        "one" -> Number(One)
        "two" -> Number(Two)
        "three" -> Number(Three)
      }
    },
  )
  |> argenie.add_string_argument(
    flags.no_default,
    NoDefault(None),
    None,
    fn(new_value: String) { NoDefault(Some(new_value)) },
  )
  |> argenie.add_mandatory_string_argument(
    flags.mandatory,
    None,
    fn(new_value: String) { Mandatory(new_value) },
  )
  |> argenie.add_bool_argument(
    flags.verbose,
    Verbose(False),
    fn(new_value: Bool) { Verbose(new_value) },
  )
  |> argenie.add_int_argument(
    flags.big,
    Big(5),
    argenie.int_validator(fn(value) {
      case value > 0 {
        True -> Ok(Nil)
        False -> Error("Value need to be greater than 0")
      }
    }),
    fn(new_value) { Big(new_value) },
  )
  |> argenie.add_string_argument(
    flags.ar,
    Ar("argh"),
    argenie.string_validator(fn(value) {
      case
        value
        |> string.starts_with("ar")
      {
        True -> Ok(Nil)
        False -> Error("Needs to start with: ar")
      }
    }),
    Ar,
  )
}

pub fn mandatory_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.mandatory)
  |> should.equal(Mandatory("was_set"))
}

pub fn mandatory_not_set_test() {
  setup_args()
  |> argenie.parse([])
  |> should.equal(Error([MandatoryMissing("mandatory")]))
}

pub fn optional_string_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--hello=\"hello was set\""])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.hello)
  |> should.equal(Hello("hello was set"))
}

pub fn optional_string_not_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.hello)
  |> should.equal(Hello("default"))
}

pub fn int_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--my_int=44"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.my_int)
  |> should.equal(Test(44))
}

pub fn int_not_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.my_int)
  |> should.equal(Test(42))
}

pub fn int_validation_failed_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--my_int=46"])
  |> should.equal(Error([Validation("my_int", NotInRange(46, 40, 45))]))
}

pub fn int_parse_error_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--my_int=4r"])
  |> should.equal(Error([ParseError("my_int", IntArg, "4r")]))
}

pub fn no_default_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--no_default=no_default_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.no_default)
  |> should.equal(NoDefault(Some("no_default_set")))
}

pub fn no_default_not_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.no_default)
  |> should.equal(NoDefault(None))
}

pub fn number_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--number=three"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.number)
  |> should.equal(Number(Three))
}

pub fn number_not_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.number)
  |> should.equal(Number(One))
}

pub fn number_invalid_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--number=five"])
  |> should.equal(Error([
    Validation("number", InvalidStringValue("five", ["one", "two", "three"])),
  ]))
}

pub fn custom_int_validation_success_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--big=5"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.big)
  |> should.equal(Big(5))
}

pub fn custom_int_validation_failed_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--big=0"])
  |> should.equal(Error([
    Validation("big", Custom("Value need to be greater than 0")),
  ]))
}

pub fn bool_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--verbose"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.verbose)
  |> should.equal(Verbose(True))
}

pub fn bool_not_set_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.verbose)
  |> should.equal(Verbose(False))
}

pub fn custom_string_validation_success_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--ar=argis"])
  |> argenie.halt_on_error()
  |> argenie.get_value(flags.ar)
  |> should.equal(Ar("argis"))
}

pub fn custom_string_validation_failed_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--ar=barkis"])
  |> should.equal(Error([Validation("ar", Custom("Needs to start with: ar"))]))
}

// TODO: These are all different experiments on how to provide a decent api for adding commands
// The main pain point is that if we allow different flag-types for different commands it will result
// in a quite cumbersome to use api with a lot of different methods depending on the number of commands
// or it will force the user code to deal with the commands and then there is no good way to provide
// built-in help for which commands are available
//
//
// Maybe one option could be to provide only a function to print commands in the same style as other
// help from argenie (once there is some style added)
pub fn subcommands_test() {
  let argenie1 = setup_args()
  let argenie2 = setup_args()
  let sub_commands =
    argenie.parse2_alt(
      #(
        #("command1", argenie1, argenie.parse),
        #("command2", argenie2, argenie.parse),
      ),
      ["command2", "--mandatory=was_set", "--ar=argis"],
    )
    |> argenie.halt_on_error2()
  let assert #(None, Some(parsed_argenie)) = sub_commands
  parsed_argenie
  |> argenie.get_value(flags.ar)
  |> should.equal(Ar("argis"))
}

pub fn subcommands_alt_test() {
  let argenie1 = setup_args()
  let argenie2 = setup_args()
  let sub_commands =
    argenie.parse2_alt(
      #(
        #("command1", #(#("sub1", argenie1, argenie.parse)), argenie.parse1_alt),
        #("command2", argenie2, argenie.parse),
      ),
      ["command1", "sub1", "--mandatory=was_set", "--ar=argis"],
    )
}

pub type Command {
  SubCommand1(parse_result: Result(Argenie(MyArg), ParseErrors))
  SubCommand2(parse_result: Result(Argenie(Command2Flags), ParseErrors))
}

pub fn subcommands_alt2_test() {
  let argenie1 = setup_args()
  let argenie2 =
    argenie.new()
    |> argenie.add_string_argument("wibble", Wibble("default"), None, Wibble)
  let sub_commands =
    argenie.parse2_alt2(
      #(
        #("command1", argenie1, argenie.parse, SubCommand1),
        #("command2", argenie2, argenie.parse, SubCommand2),
      ),
      SubCommand1,
      ["command1", "--mandatory=was_set", "--ar=argis"],
    )

  let assert SubCommand1(argenie_result) = sub_commands

  case sub_commands {
    SubCommand1(parse_result) ->
      parse_result
      |> argenie.halt_on_error
      |> fn(argenie: Argenie(MyArg)) {
        argenie
        |> argenie.get_value(flags.ar)
        |> should.equal(Ar("argis"))
        Nil
      }
    SubCommand2(parse_result) ->
      parse_result
      |> argenie.halt_on_error
      |> fn(_argenie: Argenie(Command2Flags)) {
        // Run code for command2 here
        Nil
      }
  }
}

pub type Commands {
  Command1(Sub1)
  Command2(Argenie(Command2Flags))
}

pub type Sub1 {
  Sub1(Argenie(MyArg))
}

pub type Command2Flags {
  Wibble(value: String)
}

pub fn subcommand_case_test() {
  let argenie1 = setup_args()
  let argenie2 =
    argenie.new()
    |> argenie.add_string_argument("wibble", Wibble("default"), None, Wibble)

  // TODO: Could this be combined with the parse2, parse3 .. tuple variant to build the tree in a generic way?
  let command_parser = fn(start_arguments) {
    case start_arguments {
      ["command1", "sub1", ..arguments] ->
        argenie1
        |> argenie.parse(arguments)
        |> argenie.halt_on_error()
        |> Sub1
        |> Command1
      ["command2", ..arguments] ->
        argenie2
        |> argenie.parse(arguments)
        |> argenie.halt_on_error()
        |> Command2
    }
  }

  let assert Command1(Sub1(sub1_argenie)) =
    command_parser(["command1", "sub1", "--mandatory=was_set", "--ar=argis"])
  sub1_argenie
  |> argenie.get_value(flags.ar)
  |> should.equal(Ar("argis"))

  let assert Command2(command2_argenie) =
    command_parser(["command2", "--wibble=wibble_was_set"])
  command2_argenie
  |> argenie.get_value("wibble")
  |> should.equal(Wibble("wibble_was_set"))
}
// TODO: End of command experiments
