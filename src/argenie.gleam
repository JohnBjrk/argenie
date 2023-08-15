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
  Some(fn(arg_name: String, box: Box) {
    case box {
      StringBox(string_value) -> {
        case
          valid_strings
          |> list.contains(string_value)
        {
          True -> Ok(Nil)
          False ->
            Error(Validation(
              arg_name,
              InvalidStringValue(string_value, valid_strings),
            ))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn range(min: Int, max: Int) {
  Some(fn(arg_name: String, box: Box) {
    case box {
      IntBox(int_value) -> {
        case int_value >= min && int_value < max {
          True -> Ok(Nil)
          False -> Error(Validation(arg_name, NotInRange(int_value, min, max)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn int_validator(validator: fn(Int) -> Result(Nil, String)) -> Validator {
  Some(fn(arg_name: String, box: Box) {
    case box {
      IntBox(int_value) -> {
        case validator(int_value) {
          Ok(Nil) -> Ok(Nil)
          Error(message) -> Error(Validation(arg_name, Custom(message)))
        }
      }
      _ -> Ok(Nil)
    }
  })
}

pub fn string_validator(
  validator: fn(String) -> Result(Nil, String),
) -> Validator {
  Some(fn(arg_name: String, box: Box) {
    case box {
      StringBox(string_value) -> {
        case validator(string_value) {
          Ok(Nil) -> Ok(Nil)
          Error(message) -> Error(Validation(arg_name, Custom(message)))
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
  Option(fn(String, Box) -> Result(Nil, ArgenieError))

type ArgumentMap(a) =
  Map(String, Argument(a))

pub type GenericArgument {
  GenericArgument(arg_type: ArgType, mandatory: Bool)
}

pub type GenericArgumentMap =
  Map(String, GenericArgument)

pub opaque type Argenie(a) {
  Argenie(argument_map: ArgumentMap(a))
}

pub type ArgenieError {
  // TODO: Remove this if removing parse2_alt2
  CommandHelp(commands: List(String))
  ArgumentsHelp(arguments: GenericArgumentMap)
  UnknownArgument
  ParseError(arg_name: String, expected_arg_type: ArgType, raw_value: String)
  MandatoryMissing(arg_name: String)
  Validation(arg_name: String, error: ValidationError)
  Other(message: String)
}

pub type ParseErrors =
  List(ArgenieError)

pub type ValidationError {
  InvalidStringValue(value: String, valid_values: List(String))
  NotInRange(value: Int, min: Int, max: Int)
  Custom(message: String)
}

// TODO: These are all different experiments on how to provide a decent api for adding commands
// The main pain point is that if we allow different flag-types for different commands it will result
// in a quite cumbersome to use api with a lot of different methods depending on the number of commands
// or it will force the user code to deal with the commands and then there is no good way to provide
// built-in help for which commands are available
pub fn parse2(
  sub_commands: #(#(String, Argenie(a)), #(String, Argenie(b))),
  arguments: List(String),
) -> #(
  Option(Result(Argenie(a), ParseErrors)),
  Option(Result(Argenie(b), ParseErrors)),
) {
  let #(#(sub_command1, argenie1), #(sub_command2, argenie2)) = sub_commands
  case arguments {
    [sub_command, ..sub_command_arguments] if sub_command == sub_command1 -> #(
      Some(parse(argenie1, sub_command_arguments)),
      None,
    )
    [sub_command, ..sub_command_arguments] if sub_command == sub_command2 -> #(
      None,
      Some(parse(argenie2, sub_command_arguments)),
    )
  }
}

pub fn parse2_alt(
  sub_commands: #(
    #(String, a, fn(a, List(String)) -> c),
    #(String, b, fn(b, List(String)) -> d),
  ),
  arguments: List(String),
) -> #(Option(c), Option(d)) {
  let #(#(sub_command1, argenie1, parse1), #(sub_command2, argenie2, parse2)) =
    sub_commands
  case arguments {
    [sub_command, ..sub_command_arguments] if sub_command == sub_command1 -> #(
      Some(parse1(argenie1, sub_command_arguments)),
      None,
    )
    [sub_command, ..sub_command_arguments] if sub_command == sub_command2 -> #(
      None,
      Some(parse2(argenie2, sub_command_arguments)),
    )
  }
}

pub fn parse2_alt2(
  sub_commands: #(
    #(String, a, fn(a, List(String)) -> c, fn(c) -> e),
    #(String, b, fn(b, List(String)) -> d, fn(d) -> e),
  ),
  make_help_error: fn(Result(a, ParseErrors)) -> e,
  arguments: List(String),
) -> e {
  let #(
    #(sub_command1, argenie1, parse1, make1),
    #(sub_command2, argenie2, parse2, make2),
  ) = sub_commands
  case arguments {
    ["--help"] ->
      Error([CommandHelp([sub_command1, sub_command2])])
      |> make_help_error
    [sub_command, ..sub_command_arguments] if sub_command == sub_command1 ->
      parse1(argenie1, sub_command_arguments)
      |> make1
    [sub_command, ..sub_command_arguments] if sub_command == sub_command2 ->
      parse2(argenie2, sub_command_arguments)
      |> make2
  }
}

pub fn parse1_alt(
  sub_commands: #(#(String, a, fn(a, List(String)) -> c)),
  arguments: List(String),
) -> #(Option(c), Option(d)) {
  let #(#(sub_command1, argenie1, parse1)) = sub_commands
  case arguments {
    [sub_command, ..sub_command_arguments] if sub_command == sub_command1 -> #(
      Some(parse1(argenie1, sub_command_arguments)),
      None,
    )
  }
}

pub fn halt_on_error2(
  parse2_result: #(
    Option(Result(Argenie(a), ParseErrors)),
    Option(Result(Argenie(b), ParseErrors)),
  ),
) -> #(Option(Argenie(a)), Option(Argenie(b))) {
  case parse2_result {
    #(Some(result), None) -> #(
      result
      |> halt_on_error
      |> Some,
      None,
    )
    #(None, Some(result)) -> #(
      None,
      result
      |> halt_on_error
      |> Some,
    )
  }
}

// TODO: End command experiments

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

fn to_generic(argument_map: ArgumentMap(a)) -> GenericArgumentMap {
  argument_map
  |> map.to_list
  |> list.map(fn(entry) {
    let #(arg_name, argument) = entry
    #(
      arg_name,
      GenericArgument(argument.arg_type, option.is_none(argument.arg)),
    )
  })
  |> map.from_list
}

// TODO: Maybe rename this one to safe_parse (since it returns a result) and use the name
// parse for a version that also does halt_on_error
pub fn parse(
  argenie: Argenie(a),
  arguments: List(String),
) -> Result(Argenie(a), ParseErrors) {
  let #(argument_map, errors) = case arguments {
    ["--help", ..] -> #(
      argenie.argument_map,
      [
        ArgumentsHelp(
          argenie.argument_map
          |> to_generic,
        ),
      ],
    )
    arguments -> do_parse(argenie.argument_map, [], arguments)
  }
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
              None -> [MandatoryMissing(arg_name), ..parse_errors]
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
      |> list.each(fn(error) {
        case error {
          ParseError(arg_name, expected_type, raw_value) ->
            io.println(
              "Could not parse flag: --" <> arg_name <> "=" <> raw_value <> " as " <> arg_type(
                expected_type,
              ),
            )
          MandatoryMissing(arg_name) ->
            io.println("Missing mandatory flag: \"" <> arg_name <> "\"")
          Validation(arg_name, error) -> {
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

          // TODO: Remove this if removing parse2_alt2
          CommandHelp(commands) ->
            io.println("Command help: " <> string.join(commands, ", "))
          ArgumentsHelp(arguments) -> {
            arguments
            |> io.debug()
            Nil
          }
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

        Error(_) -> Error([UnknownArgument])
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

        _ -> Error([UnknownArgument])
      }
    }
    other -> {
      other
      |> io.debug()
      Error([Other("Unexpected regex scan result")])
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
        |> option.unwrap(fn(_, _) { Ok(Nil) })
      case validate(arg_name, boxer(parsed_value)) {
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
        Error(err) -> Error([err])
      }
    }
    Error(_) -> Error([ParseError(arg_name, argument.arg_type, value)])
  }
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
