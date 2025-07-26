#!/usr/bin/env pypy

# transition table generator for stoa parser

columns = [
    "paragraph",
    "heading",
    "list",
    "comment",
    "annotation",
    "warning",
    "metadata",
    "code",
    "math",
    "footnote",
]

markups = ["inlinecode", "highlight"]

grammars = [
    ("HEADING", "nested", "&"),
    ("LIST", "nested", "="),
    ("COMMENT", "flat", "--"),
    ("ANNOTATION", "flat", "||"),
    ("WARNING", "flat", "!!"),
    ("METADATA", "flat", "::"),
    ("CODE", "fenced", "|>"),
    ("MATH", "fenced", ">>="),
    ("FOOTNOTE", "trivial", "#"),
    ("INLINECODE", "markup", "`"),
    ("HIGHLIGHT", "markup", "|"),
]


def validate_grammar(name, kind, dlm):
    if " " in dlm:
        raise ValueError(f"Delimiter '{dlm}' for {name} cannot contain spaces")

    if dlm in ["<", ">"]:
        raise ValueError(f"Delimiter '{dlm}' for {name} cannot be '<' or '>'")

    if any(ch.islower() for ch in name):
        raise ValueError(f"Grammar name '{name}' must be all uppercase")

    valid_kinds = {"trivial", "flat", "fenced", "nested", "markup"}
    if kind not in valid_kinds:
        raise ValueError(
            f"Invalid grammar kind '{kind}' for {name}. Must be one of: {valid_kinds}"
        )


def format_nim_table(table_dict, indent="      "):
    """Format a dictionary as a Nim table literal"""
    if not table_dict:
        return "{}.toTable"

    lines = ["{"]
    for key, value in table_dict.items():
        if isinstance(key, tuple):
            key_str = f"(\"{key[0]}\", '{key[1]}')"
        else:
            key_str = f'"{key}"'

        if isinstance(value, str):
            if value.islower():  # enum value
                # properly qualify enum values
                if value in columns:
                    value_str = f"ColumnKind.{value}"
                elif value in markups:
                    value_str = f"MarkupKind.{value}"
                else:
                    value_str = f'"{value}"'
            else:  # string literal
                value_str = f'"{value}"'
        else:
            value_str = str(value)

        lines.append(f"{indent}{key_str}: {value_str},")
    lines.append("   }.toTable")
    return "\n".join(lines)


def format_nim_list(items, indent="   "):
    """Format a list as a Nim sequence literal"""
    if not items:
        return "@[]"

    item_strs = []
    for item in items:
        if isinstance(item, str) and len(item) == 1:
            item_strs.append(f"'{item}'")
        else:
            item_strs.append(f'"{item}"')

    return f"@[{', '.join(item_strs)}]"


def format_nim_enum(items, indent="      "):
    """Format a list as a Nim enum definition"""
    if not items:
        return ""

    return f"{indent}" + f", {indent}".join(items)


def main():
    column_fs, column_tt, markup_symbols, markup_fs, markup_tt, keys = (
        {},
        {},
        [],
        {},
        {},
        [],
    )

    for name, kind, dlm in grammars:
        validate_grammar(name, kind, dlm)
        if kind == "markup":
            markup_symbols.append(dlm[0])
            markup_fs[name + "_F"] = name.lower()
            for i, ch in enumerate(dlm):
                if i == 0:
                    key_open, key_close = ("START", ch), (name + "_M", ch)
                    val_open, val_close = name + "_0", name + f"_{len(dlm)}"
                else:
                    key_open, key_close = (
                        (markup_tt[keys[-2]], ch),
                        (markup_tt[keys[-1]], ch),
                    )
                    val_open, val_close = name + f"_{i}", name + f"_{len(dlm) + i}"
                if i == len(dlm) - 1:
                    val_open, val_close = name + "_M", name + "_F"
                keys.append(key_open)
                markup_tt[key_open] = val_open
                keys.append(key_close)
                markup_tt[key_close] = val_close
            continue

        column_fs[name + "_F"] = name.lower()
        match kind:
            case "trivial":
                key = ("START", dlm)
                val = name + "_F"
                if key in column_tt and column_tt[key][-1] == "F":
                    raise ValueError("Delimiter collision")
                column_tt[key] = val
            case "flat" | "fenced":
                for i, ch in enumerate(dlm):
                    if i == 0:
                        key = ("START", ch)
                        val = name + "_0"
                    else:
                        key = (column_tt[keys[-1]], ch)
                        val = name + f"_{i}"
                    if key in column_tt:
                        if column_tt[key][-1] == "F":
                            raise ValueError(
                                f"Delimiter collision for {name}: '{key[1]}' conflicts with existing grammar"
                            )
                        val += "_" + column_tt[key]
                        search_key = column_tt[key]
                        for k in list(column_tt.keys()):
                            if k[0] == search_key:
                                column_tt[(val, k[1])] = column_tt[k]
                                del column_tt[k]
                    column_tt[key] = val
                    keys.append(key)
                key = (val, " ")
                column_tt[key] = name + "_F"
                key = (name + "_F", " ")
                column_tt[key] = name + "_F"
            case "nested":
                key = ("START", dlm)
                val = name + "_0"
                if key in column_tt:
                    raise ValueError(
                        f"Delimiter collision for {name}: '{key[1]}' conflicts with existing grammar"
                    )
                column_tt[key] = val
                key = (val, dlm)
                column_tt[key] = val
                key = (val, " ")
                column_tt[key] = name + "_F"
                key = (name + "_F", " ")
                column_tt[key] = name + "_F"

    nim_content = f"""# Generated transition tables for stoa parser
# This file is auto-generated. Do not edit manually.

import std/tables

type
   ColumnKind* {{.pure.}} = enum
{format_nim_enum(columns)}

   MarkupKind* {{.pure.}} = enum
{format_nim_enum(markups)}

const
   columnTransitions* = {format_nim_table(column_tt)}
   
   columnFinalStates* = {format_nim_table(column_fs)}
   
   markupSymbols* = {format_nim_list(markup_symbols)}
   
   markupTransitions* = {format_nim_table(markup_tt)}
   
   markupFinalStates* = {format_nim_table(markup_fs)}
"""

    # Write to file
    with open("src/transitions.nim", "w") as f:
        f.write(nim_content)

    print("Generated transition tables in src/transitions.nim")
    return 0


if __name__ == "__main__":
    exit(main())
