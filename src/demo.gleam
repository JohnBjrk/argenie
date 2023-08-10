import gleeunit
import gleeunit/should
import argeneric
import gleam/io
import gleam/option.{None, Option, Some}
import gleam/erlang

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
}

pub fn argeneric_test() {
  let args =
    argeneric.new()
    |> argeneric.add_string_argument(
      "hello",
      Hello("default"),
      None,
      fn(new_value: String) { Hello(new_value) },
    )
    |> argeneric.add_int_argument(
      "my_int",
      Test(42),
      argeneric.range(40, 45),
      fn(new_value: Int) { Test(new_value) },
    )
    |> argeneric.add_string_argument(
      "enum",
      Number(One),
      argeneric.one_of(["one", "two", "three"]),
      fn(new_value: String) {
        case new_value {
          "one" -> Number(One)
          "two" -> Number(Two)
          "three" -> Number(Three)
        }
      },
    )
    |> argeneric.add_string_argument(
      "no_default",
      NoDefault(None),
      None,
      fn(new_value: String) { NoDefault(Some(new_value)) },
    )
    |> argeneric.add_mandatory_string_argument(
      "mandatory",
      None,
      fn(new_value: String) { Mandatory(new_value) },
    )
    |> argeneric.add_bool_argument(
      "verbose",
      Verbose(False),
      fn(new_value: Bool) { Verbose(new_value) },
    )

  let updated_args =
    args
    |> argeneric.populate_with_string_value("hello", "yes")
    |> argeneric.populate_with_string_value("no_default", "provided")
    |> argeneric.parse(erlang.start_arguments())
    |> argeneric.halt_on_error()

  let assert Number(enum_value) =
    updated_args
    |> argeneric.get_value("enum")

  enum_value
  |> io.debug()

  let assert Hello(hello_value) =
    updated_args
    |> argeneric.get_value("hello")

  hello_value
  |> io.debug()

  let assert Test(test_value) =
    updated_args
    |> argeneric.get_value("my_int")

  test_value
  |> io.debug()

  let assert NoDefault(no_default_value) =
    updated_args
    |> argeneric.get_value("no_default")

  no_default_value
  |> io.debug()

  let assert Mandatory(mandatory_value) =
    updated_args
    |> argeneric.get_value("mandatory")

  mandatory_value
  |> io.debug()

  let assert Verbose(verbose) =
    updated_args
    |> argeneric.get_value("verbose")

  verbose
  |> io.debug()
}
