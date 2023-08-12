import gleeunit
import gleeunit/should
import argenie.{
  Custom, IntArg, InvalidStringValue, MandatoryMissing, NotInRange, ParseError,
  Validation,
}
import gleam/option.{None, Option, Some}
import gleam/string

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
  |> should.equal(Error([#("mandatory", MandatoryMissing)]))
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
  |> should.equal(Error([#("my_int", Validation(NotInRange(46, 40, 45)))]))
}

pub fn int_parse_error_test() {
  setup_args()
  |> argenie.parse(["--mandatory=was_set", "--my_int=4r"])
  |> should.equal(Error([#("my_int", ParseError(IntArg, "4r"))]))
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
    #("number", Validation(InvalidStringValue("five", ["one", "two", "three"]))),
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
    #("big", Validation(Custom("Value need to be greater than 0"))),
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
  |> should.equal(Error([#("ar", Validation(Custom("Needs to start with: ar")))]))
}
