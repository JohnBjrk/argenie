import gleam/list
import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/regex.{Match}
import gleam/io
import gleam/int
import gleam/string

pub type Box {
  StringBox(value: String)
  IntBox(value: Int)
  BoolBox(value: Bool)
}

pub type ArgType {
  StringArg
  IntArg
  BoolArg
}

pub fn string_updater(update: fn(String) -> a) {
  fn(a: Option(a), box: Box) -> Option(a) {
    case box {
      StringBox(int_value) -> Some(update(int_value))
      _ -> a
    }
  }
}

pub fn int_updater(update: fn(Int) -> a) {
  fn(a: Option(a), box: Box) {
    case box {
      IntBox(int_value) -> Some(update(int_value))
      _ -> a
    }
  }
}

pub fn bool_updater(update: fn(Bool) -> a) {
  fn(a: Option(a), box: Box) {
    case box {
      BoolBox(bool_value) -> Some(update(bool_value))
      _ -> a
    }
  }
}

pub fn one_of(valid_strings: List(String)) {
  Some(fn(box: Box) {
    case box {
      StringBox(string_value) -> {
        case
          valid_strings
          |> list.contains(string_value)
        {
          True -> Ok(Nil)
          False ->
            Error(Validation(InvalidStringValue(string_value, valid_strings)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn range(min: Int, max: Int) {
  Some(fn(box: Box) {
    case box {
      IntBox(int_value) -> {
        case int_value >= min && int_value < max {
          True -> Ok(Nil)
          False -> Error(Validation(NotInRange(int_value, min, max)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn int_validator(validator: fn(Int) -> Result(Nil, String)) -> Validator {
  Some(fn(box: Box) {
    case box {
      IntBox(int_value) -> {
        case validator(int_value) {
          Ok(Nil) -> Ok(Nil)
          Error(message) -> Error(Validation(Custom(message)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn string_validator(
  validator: fn(String) -> Result(Nil, String),
) -> Validator {
  Some(fn(box: Box) {
    case box {
      StringBox(string_value) -> {
        case validator(string_value) {
          Ok(Nil) -> Ok(Nil)
          Error(message) -> Error(Validation(Custom(message)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

type Argument(a) {
  Argument(
    arg: Option(a),
    validate_arg: Validator,
    update_arg: fn(Option(a), Box) -> Option(a),
    arg_type: ArgType,
  )
}

type Validator =
  Option(fn(Box) -> Result(Nil, ArgenieError))

type ArgumentMap(a) =
  Map(String, Argument(a))

pub opaque type Argenie(a) {
  Argenie(argument_map: ArgumentMap(a))
}

pub type ArgenieError {
  UnknownArgument
  ParseError(expected_arg_type: ArgType, raw_value: String)
  MandatoryMissing
  Validation(error: ValidationError)
  Other(message: String)
}

pub type ParseErrors =
  List(#(String, ArgenieError))

pub type ValidationError {
  InvalidStringValue(value: String, valid_values: List(String))
  NotInRange(value: Int, min: Int, max: Int)
  Custom(message: String)
}

pub fn new() -> Argenie(a) {
  Argenie(map.new())
}

pub fn add_string_argument(
  argenie: Argenie(a),
  name: String,
  argument: a,
  validator: Validator,
  update: fn(String) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(Some(argument), validator, string_updater(update), StringArg),
    ),
  )
}

pub fn add_mandatory_string_argument(
  argenie: Argenie(a),
  name: String,
  validator: Validator,
  update: fn(String) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(None, validator, string_updater(update), StringArg),
    ),
  )
}

pub fn add_int_argument(
  argenie: Argenie(a),
  name: String,
  argument: a,
  validator: Validator,
  update: fn(Int) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(Some(argument), validator, int_updater(update), IntArg),
    ),
  )
}

pub fn add_mandatory_int_argument(
  argenie: Argenie(a),
  name: String,
  validator: Validator,
  update: fn(Int) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(name, Argument(None, validator, int_updater(update), IntArg)),
  )
}

pub fn add_bool_argument(
  argenie: Argenie(a),
  name: String,
  argument: a,
  update: fn(Bool) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(Some(argument), None, bool_updater(update), BoolArg),
    ),
  )
}

// TODO: Does this make sense - if booleans always default to false
pub fn add_mandatory_bool_argument(
  argenie: Argenie(a),
  name: String,
  update: fn(Bool) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(name, Argument(None, None, bool_updater(update), BoolArg)),
  )
}

pub fn populate_with_string_value(
  argenie: Argenie(a),
  name: String,
  string_value: String,
) -> Argenie(a) {
  let assert Ok(argument) =
    argenie.argument_map
    |> map.get(name)
  let updated_argument =
    Argument(
      ..argument,
      arg: argument.update_arg(argument.arg, StringBox(string_value)),
    )
  Argenie(
    argenie.argument_map
    |> map.insert(name, updated_argument),
  )
}

pub fn parse(
  argenie: Argenie(a),
  arguments: List(String),
) -> Result(Argenie(a), ParseErrors) {
  let #(argument_map, errors) = do_parse(argenie.argument_map, [], arguments)
  case list.length(errors) {
    0 -> Ok(Argenie(argument_map))
    _ -> Error(errors)
  }
  |> check_mandatory()
}

fn do_parse(
  argument_map: ArgumentMap(a),
  errors: ParseErrors,
  arguments: List(String),
) -> #(ArgumentMap(a), ParseErrors) {
  case arguments {
    [] -> #(argument_map, errors)
    [current_argument, ..arguments] -> {
      let values =
        arguments
        |> list.take_while(fn(argument) {
          argument
          |> string.starts_with("--") != True
        })
      let remaining_arguments =
        arguments
        |> list.drop(list.length(values))
      let #(argument_map_rest, errors_rest) =
        do_parse(argument_map, errors, remaining_arguments)
      case parse_arg(argument_map, current_argument, values) {
        Ok(#(arg_name, updated_argument)) -> #(
          argument_map_rest
          |> map.insert(arg_name, updated_argument),
          errors_rest,
        )
        Error(new_errors) -> #(
          argument_map_rest,
          new_errors
          |> list.append(errors_rest),
        )
      }
    }
  }
}

fn check_mandatory(
  argenie: Result(Argenie(a), ParseErrors),
) -> Result(Argenie(a), ParseErrors) {
  case argenie {
    Error(_) as err -> err
    Ok(argenie) -> {
      let errors =
        argenie.argument_map
        |> map.to_list()
        |> list.fold(
          [],
          fn(parse_errors, entry) {
            let assert #(arg_name, arg) = entry
            case arg.arg {
              Some(_) -> parse_errors
              None -> [#(arg_name, MandatoryMissing), ..parse_errors]
            }
          },
        )
      case
        errors
        |> list.length()
      {
        0 -> Ok(argenie)
        _ -> Error(errors)
      }
    }
  }
}

pub fn halt_on_error(argenie_result: Result(Argenie(a), ParseErrors)) {
  case argenie_result {
    Ok(argenie) -> argenie
    Error(parse_errors) -> {
      parse_errors
      |> list.each(fn(entry) {
        let assert #(arg_name, error) = entry
        case error {
          ParseError(expected_type, raw_value) ->
            io.println(
              "Could not parse flag: --" <> arg_name <> "=" <> raw_value <> " as " <> arg_type(
                expected_type,
              ),
            )
          MandatoryMissing ->
            io.println("Missing mandatory flag: \"" <> arg_name <> "\"")
          Validation(error) -> {
            io.println("Validation error for flag \"" <> arg_name <> "\"")
            case error {
              InvalidStringValue(value, valid_values) ->
                io.println(
                  "\tInvalid string value. Got: \"" <> value <> "\", expected: " <> string.join(
                    valid_values,
                    ",",
                  ),
                )
              NotInRange(value, min, max) ->
                io.println(
                  "\tValue x = " <> int.to_string(value) <> " not in range: " <> int.to_string(
                    min,
                  ) <> " <= x < " <> int.to_string(max),
                )
              Custom(message) -> io.println("\t" <> message)
            }
          }
          Other(message) -> io.println(message)
          UnknownArgument -> io.println("UNKNOWN ARGUMENT")
        }
      })
      halt(1)
      panic as "Unreachable"
    }
  }
}

fn arg_type(arg_type: ArgType) -> String {
  case arg_type {
    StringArg -> "string"
    IntArg -> "integer"
    BoolArg -> "boolean"
  }
}

fn parse_arg(
  argument_map: ArgumentMap(a),
  arg: String,
  values: List(String),
) -> Result(#(String, Argument(a)), ParseErrors) {
  let assert Ok(arg_re) = regex.from_string("--(\\w+)=\"?([^\"]+)\"?|--(\\w+)")
  case
    arg_re
    |> regex.scan(arg)
  {
    [Match(_, [Some(arg_name), Some(arg_value)])] -> {
      case
        argument_map
        |> map.get(arg_name)
      {
        Ok(argument) -> {
          case argument.arg_type {
            BoolArg ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                "true",
                parse_bool,
                BoolBox,
              )
            StringArg ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                arg_value,
                parse_string,
                StringBox,
              )
            IntArg ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                arg_value,
                int.parse,
                IntBox,
              )
            _ -> Ok(#(arg_name, argument))
          }
        }

        Error(_) -> Error([#("UNKNOWN", UnknownArgument)])
      }
    }
    [Match(_, [None, None, Some(arg_name)])] -> {
      case
        argument_map
        |> map.get(arg_name)
      {
        Ok(argument) -> {
          case argument.arg_type, values {
            BoolArg, _ ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                "true",
                parse_bool,
                BoolBox,
              )
            StringArg, [arg_value, ..] ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                arg_value,
                parse_string,
                StringBox,
              )
            IntArg, [arg_value, ..] ->
              parse_validate_and_update_argument(
                arg_name,
                argument,
                arg_value,
                int.parse,
                IntBox,
              )
            _, _ -> Ok(#(arg_name, argument))
          }
        }

        _ -> Error([#("UNKNOWN", UnknownArgument)])
      }
    }
    other -> {
      other
      |> io.debug()
      Error([#("UNKNOWN", Other("Unexpected regex scan result"))])
    }
  }
}

fn parse_bool(raw_value: String) -> Result(Bool, Nil) {
  case raw_value {
    "True" | "true" -> Ok(True)
    "False" | "false" -> Ok(False)
    _ -> Error(Nil)
  }
}

fn parse_string(raw_value) -> Result(String, Nil) {
  Ok(raw_value)
}

fn parse_validate_and_update_argument(
  arg_name: String,
  argument: Argument(a),
  value: String,
  parse: fn(String) -> Result(b, Nil),
  boxer: fn(b) -> Box,
) {
  case parse(value) {
    Ok(parsed_value) -> {
      let validate =
        argument.validate_arg
        |> option.unwrap(fn(_) { Ok(Nil) })
      case validate(boxer(parsed_value)) {
        Ok(_) -> {
          #(
            arg_name,
            Argument(
              ..argument,
              arg: argument.update_arg(argument.arg, boxer(parsed_value)),
            ),
          )
          |> Ok
        }
        Error(err) -> Error([#(arg_name, err)])
      }
    }
    Error(_) -> Error([#(arg_name, ParseError(argument.arg_type, value))])
  }
}

pub fn populate_with_int_value(
  argenie: Argenie(a),
  name: String,
  int_value: Int,
) -> Argenie(a) {
  let assert Ok(argument) =
    argenie.argument_map
    |> map.get(name)
  let updated_argument =
    Argument(
      ..argument,
      arg: argument.update_arg(argument.arg, IntBox(int_value)),
    )
  Argenie(
    argenie.argument_map
    |> map.insert(name, updated_argument),
  )
}

pub fn get_value(argenie: Argenie(a), name: String) {
  let assert Ok(argument) =
    argenie.argument_map
    |> map.get(name)
  let assert Some(value) = argument.arg
  value
}

@target(erlang)
@external(erlang, "erlang", "halt")
fn halt(a: Int) -> Nil
