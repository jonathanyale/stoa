# Generated transition tables for stoa parser
# This file is auto-generated. Do not edit manually.

import std/tables

type
   ColumnKind* {.pure.} = enum
      paragraph, heading, list, comment, annotation, warning, metadata, code, math, footnote

   MarkupKind* {.pure.} = enum
      inlinecode, highlight

const
   columnTransitions* = {
      ("START", '&'): "HEADING_0",
      ("HEADING_0", '&'): "HEADING_0",
      ("HEADING_0", ' '): "HEADING_F",
      ("HEADING_F", ' '): "HEADING_F",
      ("START", '='): "LIST_0",
      ("LIST_0", '='): "LIST_0",
      ("LIST_0", ' '): "LIST_F",
      ("LIST_F", ' '): "LIST_F",
      ("START", '-'): "COMMENT_0",
      ("COMMENT_0", '-'): "COMMENT_1",
      ("COMMENT_1", ' '): "COMMENT_F",
      ("COMMENT_F", ' '): "COMMENT_F",
      ("START", '|'): "CODE_0_ANNOTATION_0",
      ("ANNOTATION_1", ' '): "ANNOTATION_F",
      ("ANNOTATION_F", ' '): "ANNOTATION_F",
      ("START", '!'): "WARNING_0",
      ("WARNING_0", '!'): "WARNING_1",
      ("WARNING_1", ' '): "WARNING_F",
      ("WARNING_F", ' '): "WARNING_F",
      ("START", ':'): "METADATA_0",
      ("METADATA_0", ':'): "METADATA_1",
      ("METADATA_1", ' '): "METADATA_F",
      ("METADATA_F", ' '): "METADATA_F",
      ("CODE_0_ANNOTATION_0", '|'): "ANNOTATION_1",
      ("CODE_0_ANNOTATION_0", '>'): "CODE_1",
      ("CODE_1", ' '): "CODE_F",
      ("CODE_F", ' '): "CODE_F",
      ("START", '>'): "MATH_0",
      ("MATH_0", '>'): "MATH_1",
      ("MATH_1", '='): "MATH_2",
      ("MATH_2", ' '): "MATH_F",
      ("MATH_F", ' '): "MATH_F",
      ("START", '#'): "FOOTNOTE_F",
   }.toTable

   columnFinalStates* = {
      "HEADING_F": ColumnKind.heading,
      "LIST_F": ColumnKind.list,
      "COMMENT_F": ColumnKind.comment,
      "ANNOTATION_F": ColumnKind.annotation,
      "WARNING_F": ColumnKind.warning,
      "METADATA_F": ColumnKind.metadata,
      "CODE_F": ColumnKind.code,
      "MATH_F": ColumnKind.math,
      "FOOTNOTE_F": ColumnKind.footnote,
   }.toTable

   markupSymbols* = @['`', '|']

   markupTransitions* = {
      ("START", '`'): "INLINECODE_M",
      ("INLINECODE_M", '`'): "INLINECODE_F",
      ("START", '|'): "HIGHLIGHT_M",
      ("HIGHLIGHT_M", '|'): "HIGHLIGHT_F",
   }.toTable

   markupFinalStates* = {
      "INLINECODE_F": MarkupKind.inlinecode,
      "HIGHLIGHT_F": MarkupKind.highlight,
   }.toTable
