import std/[tables, times]
import transitions

type
   Res* = object
      metadata*: Table[string, string]
      refs*: Table[string, string]
      document*: string
      description*: string
      headingCount*: int
      footnotes*: string

   Lexer* = object
      lineno*: int
      offset*: int
      cur*: string
      char*: char
      line*: string
      lines*: seq[string]
      lastColumnKind*: ColumnKind

   BlogCard* = object
      title*: string
      description*: string
      published*: DateTime
      tags*: seq[string]
      url*: string

   ArchiveData* = object
      homeCards*: seq[BlogCard]
      tagCards*: Table[string, seq[BlogCard]]

proc zeroed*(lexer: var Lexer) =
   lexer.offset = 0
   lexer.lineno = -1
   lexer.cur = ""
   lexer.char = '\0'
   lexer.line = ""
   lexer.lines = @[]
   lexer.lastColumnKind = ColumnKind.paragraph

proc zeroed*(res: var Res) =
   res.metadata = initTable[string, string]()
   res.refs = initTable[string, string]()
   res.document = ""
   res.description = ""
   res.headingCount = 0

proc forwardChar*(lexer: var Lexer): bool =
   inc lexer.offset
   if lexer.offset >= lexer.line.len: return false
   lexer.char = lexer.line[lexer.offset]
   true

proc forwardLine*(lexer: var Lexer): bool =
   inc lexer.lineno
   if lexer.lineno >= lexer.lines.len: return false
   lexer.line = lexer.lines[lexer.lineno]
   lexer.offset = 0
   lexer.char = if lexer.line.len > 0: lexer.line[0] else: '\0'
   true

