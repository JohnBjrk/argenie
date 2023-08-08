import gleam/list.{Continue, Stop}
import gleam/map.{Map}
import gleam/option.{None, Option, Some}
import gleam/regex.{Match}
import gleam/io
import gleam/int
import gleam/result

pub type Box {
  StringBox(value: String)
  IntBox(value: Int)
}

pub type ArgType {
  StringArg
  IntArg
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

pub fn one_of(valid_strings: List(String)) {
  Some(fn(box: Box) {
    case box {
      StringBox(string_value) -> {
        case
          valid_strings
          |> list.contains(string_value)
        {
          True -> Ok(Nil)
          False -> Error("Invalid value (enum)")
        }
      }
      IntBox(_) -> Ok(Nil)
    }
  })
}

type Argument(a) {
  Argument(
    arg: Option(a),
    validate_arg: Option(fn(Box) -> Result(Nil, String)),
    update_arg: fn(Option(a), Box) -> Option(a),
    arg_type: ArgType,
  )
}

type ArgumentMap(a) =
  Map(String, Argument(a))

pub opaque type Argenie(a) {
  Argenie(argument_map: ArgumentMap(a))
}

pub type ArgenieError {
  ParseError(expected_arg_type: ArgType, raw_value: String)
  MandatoryMissing
  Other(message: String)
}

pub type ParseErrors =
  Map(String, ArgenieError)

pub fn new() -> Argenie(a) {
  Argenie(map.new())
}

pub fn add_string_argument(
  argenie: Argenie(a),
  name: String,
  argument: a,
  update: fn(String) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(Some(argument), None, string_updater(update), StringArg),
    ),
  )
}

pub fn add_mandatory_string_argument(
  argenie: Argenie(a),
  name: String,
  update: fn(String) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(name, Argument(None, None, string_updater(update), StringArg)),
  )
}

pub fn add_int_argument(
  argenie: Argenie(a),
  name: String,
  argument: a,
  update: fn(Int) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(
      name,
      Argument(Some(argument), None, int_updater(update), IntArg),
    ),
  )
}

pub fn add_mandatory_int_argument(
  argenie: Argenie(a),
  name: String,
  update: fn(Int) -> a,
) -> Argenie(a) {
  Argenie(
    argenie.argument_map
    |> map.insert(name, Argument(None, None, int_updater(update), IntArg)),
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
  argenie
  |> update_values(arguments)
  |> check_mandatory()
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
          map.new(),
          fn(parse_errors, entry) {
            let assert #(arg_name, arg) = entry
            case arg.arg {
              Some(_) -> parse_errors
              None ->
                parse_errors
                |> map.insert(arg_name, MandatoryMissing)
            }
          },
        )
      case
        errors
        |> map.size()
      {
        0 -> Ok(argenie)
        _ -> Error(errors)
      }
    }
  }
}

fn update_values(
  argenie: Argenie(a),
  arguments: List(String),
) -> Result(Argenie(a), ParseErrors) {
  let updated_argument_map =
    arguments
    |> list.fold_until(
      Ok(argenie.argument_map),
      fn(argument_map_result, arg) {
        let assert Ok(argument_map) = argument_map_result
        case
          argument_map
          |> parse_arg(arg)
        {
          Ok(_) as argument_map_result -> Continue(argument_map_result)
          Error(_) as err -> Stop(err)
        }
      },
    )
  case updated_argument_map {
    Ok(updated_argument_map) -> Ok(Argenie(argument_map: updated_argument_map))
    Error(msg) -> Error(msg)
  }
}

pub fn halt_on_error(argenie_result: Result(Argenie(a), ParseErrors)) {
  case argenie_result {
    Ok(argenie) -> argenie
    Error(parse_errors) -> {
      // io.println(message)
      parse_errors
      |> map.to_list()
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
          Other(message) -> io.println(message)
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
  }
}

fn parse_arg(
  argument_map: ArgumentMap(a),
  arg: String,
) -> Result(ArgumentMap(a), ParseErrors) {
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
          let updated_argument = case argument.arg_type {
            StringArg ->
              Ok(
                Argument(
                  ..argument,
                  arg: argument.update_arg(argument.arg, StringBox(arg_value)),
                ),
              )
            IntArg -> {
              case int.parse(arg_value) {
                Ok(int_value) ->
                  Ok(
                    Argument(
                      ..argument,
                      arg: argument.update_arg(argument.arg, IntBox(int_value)),
                    ),
                  )
                Error(_) ->
                  // Error(
                  //   "Could not parse flag: --" <> arg_name <> "=" <> arg_value <> " as an integer",
                  // )
                  Error(map.from_list([
                    #(arg_name, ParseError(argument.arg_type, arg_value)),
                  ]))
              }
            }
          }
          case updated_argument {
            Ok(updated_argument) -> {
              argument_map
              |> map.insert(arg_name, updated_argument)
              |> Ok
            }
            Error(msg) -> Error(msg)
          }
        }

        Error(_) -> Ok(argument_map)
      }
    }
    other -> {
      other
      |> io.debug()
      Error(map.from_list([#("UNKNOWN", Other("Unexpected regex scan result"))]))
    }
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
