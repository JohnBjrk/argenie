import argenie
import gleam/io
import gleam/option.{None, Option, Some}
import gleam/erlang
import gleam/string

pub fn main() {
  argeneric_test()
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

pub fn argeneric_test() {
  let args =
    argenie.new()
    |> argenie.add_string_argument(
      "hello",
      Hello("default"),
      None,
      fn(new_value: String) { Hello(new_value) },
    )
    |> argenie.add_int_argument(
      "my_int",
      Test(42),
      argenie.range(40, 45),
      fn(new_value: Int) { Test(new_value) },
    )
    |> argenie.add_string_argument(
      "enum",
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
      "no_default",
      NoDefault(None),
      None,
      fn(new_value: String) { NoDefault(Some(new_value)) },
    )
    |> argenie.add_mandatory_string_argument(
      "mandatory",
      None,
      fn(new_value: String) { Mandatory(new_value) },
    )
    |> argenie.add_bool_argument(
      "verbose",
      Verbose(False),
      fn(new_value: Bool) { Verbose(new_value) },
    )
    |> argenie.add_int_argument(
      "big_int",
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
      "ar",
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

  let parsed_args =
    args
    |> argenie.parse(erlang.start_arguments())
    |> argenie.halt_on_error()

  let assert Number(enum_value) =
    parsed_args
    |> argenie.get_value("enum")

  enum_value
  |> io.debug()

  let assert Hello(hello_value) =
    parsed_args
    |> argenie.get_value("hello")

  hello_value
  |> io.debug()

  let assert Test(test_value) =
    parsed_args
    |> argenie.get_value("my_int")

  test_value
  |> io.debug()

  let assert NoDefault(no_default_value) =
    parsed_args
    |> argenie.get_value("no_default")

  no_default_value
  |> io.debug()

  let assert Mandatory(mandatory_value) =
    parsed_args
    |> argenie.get_value("mandatory")

  mandatory_value
  |> io.debug()

  let assert Verbose(verbose) =
    parsed_args
    |> argenie.get_value("verbose")

  verbose
  |> io.debug()

  parsed_args
  |> argenie.get_value("big_int")
  |> io.debug()
  parsed_args
  |> argenie.get_value("ar")
  |> io.debug()
}
