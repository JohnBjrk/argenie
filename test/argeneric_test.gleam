import gleeunit
import gleeunit/should
import argeneric
import gleam/io
import gleam/option.{None, Option, Some}

pub fn main() {
  gleeunit.main()
}

pub type Enumeration {
  One
  Two
  Three
}

pub type MyArg {
  Hello(value: String)
  Test(value: Int)
  Enum(value: Enumeration)
  NoDefault(value: Option(String))
  Mandatory(value: String)
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
      Hello("default"),
      None,
      fn(new_value: Int) { Test(new_value) },
    )
    |> argeneric.add_string_argument(
      "enum",
      Enum(One),
      None,
      fn(new_value: String) {
        case new_value {
          "one" -> Enum(One)
          "two" -> Enum(Two)
          "three" -> Enum(Three)
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

  let updated_args =
    args
    |> argeneric.populate_with_string_value("hello", "yes")
    // |> argeneric.populate_with_int_value("my_int", 42)
    // |> argeneric.populate_with_string_value("enum", "two")
    |> argeneric.populate_with_string_value("no_default", "provided")
    |> argeneric.populate_with_string_value("mandatory", "added it")
    |> argeneric.parse2(["--enum=two", "--my_int=44"])
    |> argeneric.halt_on_error()

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

  let assert Enum(enum_value) =
    updated_args
    |> argeneric.get_value("enum")

  enum_value
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

  updated_args
  |> argeneric.parse2(["--apa=bepa"])
}
