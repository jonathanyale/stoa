import std/[tables, strutils, strformat, times, sequtils, os, algorithm, parseopt]
import transitions, templates, types

discard """
stoac is the compiler from `.stoa` to `.html`.

NOTE: stoac is targeted at my personal blogsite.

stoac processes each stoa file in a single linear pass, line by line, without
building token trees or ASTs. the core abstraction is the `Lexer`, which is a
stateful string builder in action.

stoac’s translation pipeline is a strict, single-pass process:
1. detect column kind via finite state machine
2. route to the appropriate combinator
3. parse inlines within the column
4. append output and continue
"""

proc escapeHtmlChar(c: char): string =
   case c
   of '&': "&amp;"
   of '<': "&lt;"
   of '>': "&gt;"
   else: $c

proc escapeHtml(s: string): string = s.mapIt(escapeHtmlChar(it)).join("")

proc appendColumn(lexer: var Lexer, res: var Res, ckind: ColumnKind) =
   res.document &= lexer.cur
   if ckind == heading: inc res.headingCount
   if res.headingCount == 1: res.description &= lexer.cur
   lexer.cur = ""

proc getColumnKind(line: string): ColumnKind =
   var state = "START"
   for c in line:
      let key = (state, c)
      if key in columnTransitions: state = columnTransitions[key]
      elif state == "START": return paragraph
      elif state in columnFinalStates and c != ' ': return columnFinalStates[state]
      else: return paragraph

proc parseMarkup(lexer: var Lexer) =
   var
      state = "START"
      cur = ""
   while true:
      let key = (state, lexer.char)
      if key in markupTransitions: state = markupTransitions[key]
      elif state[^1] == 'M': cur &= escapeHtmlChar(lexer.char)
      else: break
      if state in markupFinalStates:
         lexer.cur &= fmt "<span class='{$markupFinalStates[state]}'>{cur}</span>"
         break
      if not lexer.forwardChar: break

proc parseLink(lexer: var Lexer) =
   var
      text = ""
      link = ""
      tmp = ""
   if lexer.char == '[': discard lexer.forwardChar
   while lexer.char != ']':
      tmp &= escapeHtmlChar(lexer.char)
      if not lexer.forwardChar: break
   if tmp.len > 0 and tmp[0] == '#':
      var idx = if tmp.len > 1: tmp[1..^1] else: ""
      lexer.cur &= fmt"<a id='ref{idx}' href='#footnote{idx}' class='footnote-ref'>[{idx}]</a>"
      return
   let parts = tmp.split(" | ")
   text = parts[0].strip
   link = if parts.len > 1: parts[1].strip else: parts[0].strip
   lexer.cur &= fmt"<a href='{link}' rel='noopener noreferrer' target=_blank>{text}</a>"
   discard lexer.forwardChar

proc parseInlineElements(lexer: var Lexer) =
   while true:
      if lexer.char in markupSymbols: lexer.parseMarkup
      elif lexer.char == '[': lexer.parseLink
      else: lexer.cur &= escapeHtmlChar(lexer.char)
      if not lexer.forwardChar: break

proc parseContentWithContinuation(lexer: var Lexer, content: string) =
   lexer.line = content.strip
   lexer.offset = 0
   if lexer.line.len > 0:
      lexer.char = lexer.line[lexer.offset]
      lexer.parseInlineElements
   var appendBr = false
   while true:
      if not lexer.forwardLine: break
      if lexer.line.isEmptyOrWhitespace: appendBr = true
      elif lexer.char == ' ':
         if appendBr: lexer.cur &= "<br/>"
         lexer.cur &= " "
         lexer.line = lexer.line.strip
         if lexer.line.len > 0:
            lexer.offset = 0
            lexer.char = lexer.line[lexer.offset]
            lexer.parseInlineElements
      else: break

proc parseParagraph(lexer: var Lexer) =
   lexer.cur &= "<p>"
   if lexer.lastColumnKind == list: lexer.cur &= "<br/>"
   while true:
      if lexer.line.isEmptyOrWhitespace: lexer.cur &= "<br/>"
      else: lexer.parseInlineElements
      if not lexer.forwardLine: break
      let ckind = lexer.line.getColumnKind
      if ckind != paragraph: break
      else: lexer.cur &= " "
   lexer.cur &= "</p>"

proc parseHeading(lexer: var Lexer) =
   let parts = lexer.line.splitWhitespace(1)
   let level = if parts.len > 0: parts[0].len else: 0
   let content = if parts.len > 1: parts[1] else: ""
   lexer.cur &= fmt"<h{level}>"
   lexer.parseContentWithContinuation(content)
   lexer.cur &= fmt"</h{level}>"

proc parseNested(lexer: var Lexer, ckind: ColumnKind) =
   let parts = lexer.line.splitWhitespace(1)
   let level = if parts.len > 0: parts[0].len else: 0
   let content = if parts.len > 1: parts[1] else: ""
   let classStr = case ckind
      of list: fmt"list-{level}"
      else: ""
   lexer.cur &= fmt"<div class='{classStr}'>"
   lexer.parseContentWithContinuation(content)
   lexer.cur &= "</div>"

proc parseSidenote(lexer: var Lexer, ckind: ColumnKind) =
   let classStr = case ckind
      of annotation: "annotation"
      of warning: "warning"
      else: "comment"
   lexer.cur &= fmt"<div class='sidenote {classStr}'>"
   let parts = lexer.line.splitWhitespace(1)
   let content = if parts.len > 1: parts[1] else: ""
   lexer.parseContentWithContinuation(content)
   lexer.cur &= "</div>"

proc parseCode(lexer: var Lexer) =
   let parts = lexer.line.splitWhitespace(1)
   let lang = if parts.len > 1: parts[1].strip else: ""
   var depth = 0
   lexer.cur &= "<div class='code-block'>"
   lexer.cur &= fmt"<pre><code>"
   discard lexer.forwardLine
   while lexer.line.strip != "|>" or depth != 0:
      # nested code blocks
      if lexer.line.strip == "|>": depth -= 1
      elif lexer.line.getColumnKind == code: inc depth
      lexer.cur &= escapeHtml(lexer.line) & "\n"
      if not lexer.forwardLine: break
   lexer.cur &= "</code></pre>"
   if lang != "": lexer.cur &= fmt"<span class='code-lang'>{lang}</span>"
   lexer.cur &= "</div>"
   discard lexer.forwardLine

proc parseMath(lexer: var Lexer) =
   lexer.cur &= "<div class='math'><pre>"
   discard lexer.forwardLine
   while lexer.line.strip != ">>=":
      lexer.cur &= escapeHtml(lexer.line) & "\n"
      if not lexer.forwardLine: break
   lexer.cur &= fmt"</pre></div>"
   discard lexer.forwardLine

proc parseMetadata(lexer: var Lexer, res: var Res) =
   let parts = lexer.line.split(":: ", 1)[1].strip.split('&', 1)
   let key = if parts.len > 0: parts[0].strip else: ""
   let value = if parts.len > 1: parts[1].strip else: ""
   res.metadata[key] = value
   discard lexer.forwardLine

proc parseFootnote(lexer: var Lexer, res: var Res) =
   let parts = lexer.line.splitWhitespace(1)
   let idx = if parts.len > 0 and parts[0].strip.len > 1: parts[0].strip[1..^1] else: ""
   var content = if parts.len > 1: parts[1].strip else: ""
   lexer.parseContentWithContinuation(content)
   res.refs[idx] = lexer.cur
   lexer.cur = ""

proc parseColumn(lexer: var Lexer, res: var Res, ckind: ColumnKind) =
   case ckind
   of heading: lexer.parseHeading
   of list: lexer.parseNested(ckind)
   of comment: lexer.parseSidenote(ckind)
   of annotation: lexer.parseSidenote(ckind)
   of warning: lexer.parseSidenote(ckind)
   of metadata: lexer.parseMetadata(res)
   of code: lexer.parseCode
   of math: lexer.parseMath
   of footnote: lexer.parseFootnote(res)
   else: lexer.parseParagraph
   lexer.appendColumn(res, ckind)
   lexer.lastColumnKind = ckind

proc parseLine(lexer: var Lexer, res: var Res) =
   var ckind = lexer.line.getColumnKind
   lexer.parseColumn(res, ckind)

proc parseStoaFile(
   lexer: var Lexer, res: var Res, lines: seq[string]
) =
   lexer.zeroed
   lexer.lines = lines
   res.zeroed
   # when zeroed, lexer.lineno is set to -1
   # this would ensure the first line of the file being parsed correctly
   discard lexer.forwardLine
   while lexer.lineno < lines.len:
      lexer.parseLine(res)

   # collect footnote content separately
   for idx, content in res.refs:
      res.footnotes &= fmt"<div id='footnote{idx}' class='footnote'><a href='#ref{idx}' class='footnote-ref'>[{idx}]</a> {content}</div>"

proc addMetadataField(
   content: var string, res: Res, fields: varargs[string]
) =
   for field in fields:
      if field in res.metadata: content &= buildMetaField(field, res.metadata[field])

proc fillInMetadata(res: Res): string =
   var content = ""
   if "title" in res.metadata: content &= buildTitle(res.metadata["title"])
   content.addMetadataField(
      res, ["tags", "published", "created", "updated"]
   )
   return content

proc generateBlogMetadata(res: Res): string =
   let title = res.metadata.getOrDefault("title", "")
   let tags = res.metadata.getOrDefault("tags", "")
   let published = res.metadata.getOrDefault("published", "")
   return buildBlogMetadata(title, tags, published)

proc injectHtml(res: Res, filepath: string) =
   let result = buildBlogPostTemplate(res.fillInMetadata,
         res.generateBlogMetadata, res.document, res.footnotes)
   writeFile(filepath, result)

proc parseDateTime(dateStr: string): DateTime =
   if dateStr == "": return now()

   let parts = dateStr.toLower().split(", ")
   if parts.len != 2: return now()

   let yearStr = parts[1].strip()
   let monthDayParts = parts[0].split(" ")
   if monthDayParts.len != 2: return now()

   let monthStr = monthDayParts[0].strip()
   let dayStr = monthDayParts[1].strip()

   let monthMap = {
      "january": 1, "february": 2, "march": 3, "april": 4,
      "may": 5, "june": 6, "july": 7, "august": 8,
      "september": 9, "october": 10, "november": 11, "december": 12
   }.toTable()

   try:
      let year = yearStr.parseInt()
      let day = dayStr.parseInt()
      let month = monthMap.getOrDefault(monthStr, 1)

      return dateTime(year, Month(month), day, 0, 0, 0, 0, utc())
   except:
      return now()

proc extractBlogCard(res: Res, filepath: string, inputDir: string): BlogCard =
   var card = BlogCard()
   card.title = res.metadata.getOrDefault("title", "Untitled")
   card.published = res.metadata.getOrDefault("published", "").parseDateTime
   card.description = res.description

   let relPath = filepath.relativePath(inputDir).replace(".stoa", ".html")
   card.url = "pages/" & relPath

   let tagsStr = res.metadata.getOrDefault("tags", "")
   if tagsStr != "": card.tags = tagsStr.split(",").mapIt(it.strip())

   return card

proc processStoaFile(inputPath: string, outputDir: string,
      inputDir: string): BlogCard =
   let content = readFile(inputPath).splitLines()
   var lexer = Lexer()
   var res = Res()

   parseStoaFile(lexer, res, content)

   let relativePath = inputPath.relativePath(inputDir)
   let outputPath = outputDir / relativePath.replace(".stoa", ".html")
   let outputDirPath = parentDir(outputPath)
   if not dirExists(outputDirPath): createDir(outputDirPath)

   injectHtml(res, outputPath)

   return extractBlogCard(res, inputPath, inputDir)

proc walkStoaFiles(baseDir: string): seq[string] =
   var files: seq[string] = @[]

   for path in walkDirRec(baseDir):
      if path.endsWith(".stoa"): files.add(path)

   return files

proc generateArchiveData(cards: seq[BlogCard]): ArchiveData =
   var archive = ArchiveData()

   # sort cards by published date (newest first)
   archive.homeCards = cards.sorted(proc(a, b: BlogCard): int =
      cmp(b.published, a.published))

   archive.tagCards = initTable[string, seq[BlogCard]]()
   for card in cards:
      for tag in card.tags:
         if tag notin archive.tagCards: archive.tagCards[tag] = @[]
         archive.tagCards[tag].add(card)

   for tag in archive.tagCards.keys:
      archive.tagCards[tag] = archive.tagCards[tag].sorted(
         proc(a, b: BlogCard): int = cmp(b.published, a.published))

   return archive

proc generateBlogCardHtml(card: BlogCard): string =
   let formattedDate = card.published.format("yyyy-MM-dd")
   let tagsHtml = card.tags.mapIt(fmt"<span class='tag'>{it}</span>").join(" ")

   return buildBlogCard(card.title, card.description, card.url, formattedDate, tagsHtml)

proc generateIndexHtml(archive: ArchiveData): string =
   let cssLinks = @[CSS_RESET, CSS_BASE, CSS_HOME]
   let sidebar = buildSidebarWithNav(homeActive = true)

   var mainContent = MAIN_CONTENT_OPEN & CONTENT_MAIN_OPEN & "<section>" &
         buildPostsHeader("Latest Posts", archive.homeCards.len) & "<div>"
   for card in archive.homeCards:
      mainContent &= generateBlogCardHtml(card)
   mainContent &= "</div></section>" & CONTENT_MAIN_CLOSE & MAIN_CONTENT_CLOSE
   let bodyContent = "<div>" & sidebar & mainContent & "</div>"

   return buildHtmlPage("jonathanyale log", cssLinks, bodyContent)

proc generateTagPageHtml(tagName: string, cards: seq[BlogCard]): string =
   let cssLinks = @[CSS_RESET_TAG, CSS_BASE_TAG, CSS_HOME_TAG, CSS_TAG_TAG]
   let sidebar = buildSidebarWithNav(tagActive = true, useParentPaths = true)
   var tagContent = MAIN_CONTENT_OPEN & CONTENT_MAIN_OPEN & "<section>" &
         TAG_BACK_OPEN & BACK_LINK_TAGS & TAG_BACK_CLOSE & buildTagHeader(
         tagName, cards.len) & "<div>"
   for card in cards:
      var tagCard = card
      tagCard.url = "../" & card.url
      tagContent &= generateBlogCardHtml(tagCard)
   tagContent &= "</div></section>" & CONTENT_MAIN_CLOSE & MAIN_CONTENT_CLOSE
   let bodyContent = "<div>" & sidebar & tagContent & "</div>"

   return buildHtmlPage(tagName, cssLinks, bodyContent)

proc generateTagsMainHtml(archive: ArchiveData): string =
   let cssLinks = @[CSS_RESET, CSS_BASE, CSS_HOME, CSS_TAG]
   let sidebar = buildSidebarWithNav(tagActive = true)
   var tagsContent = MAIN_CONTENT_OPEN & CONTENT_MAIN_OPEN & TAGS_CLOUD_OPEN
   var sortedTags: seq[(string, seq[BlogCard])] = @[]
   for tag, cards in archive.tagCards.pairs:
      sortedTags.add((tag, cards))
   sortedTags.sort(proc(a, b: (string, seq[BlogCard])): int = cmp(a[0], b[0]))
   for (tag, cards) in sortedTags:
      let count = cards.len
      tagsContent &= buildTagLink(tag, count)
   tagsContent &= TAGS_CLOUD_CLOSE & CONTENT_MAIN_CLOSE & MAIN_CONTENT_CLOSE
   let bodyContent = "<div>" & sidebar & tagsContent & "</div>"

   return buildHtmlPage("jonathanyale log", cssLinks, bodyContent)

proc generateWebPages(archive: ArchiveData, outputDir: string) =
   let indexHtml = generateIndexHtml(archive)
   writeFile(outputDir / "index.html", indexHtml)

   let tagMainHtml = generateTagsMainHtml(archive)
   writeFile(outputDir / "tag.html", tagMainHtml)

   let tagsDir = outputDir / "tags"
   if not dirExists(tagsDir):
      createDir(tagsDir)

   for tag, cards in archive.tagCards.pairs:
      let tagHtml = generateTagPageHtml(tag, cards)
      let tagPath = fmt"{tagsDir}/{tag}.html"
      writeFile(tagPath, tagHtml)

proc generateRssFeed(archive: ArchiveData): string =
   let baseUrl = "https://jonathanyale.github.io"
   let buildDate = now().format("ddd, dd MMM yyyy HH:mm:ss") & " +0000"

   var rss = """<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
<channel>
<title>λboredom</title>
<link>""" & baseUrl &
         """</link>
<description>Recent content on λboredom</description>
<generator>stoac</generator>
<language>en</language>
<lastBuildDate>""" & buildDate & """</lastBuildDate>
"""

   for card in archive.homeCards:
      let pubDate = card.published.format("ddd, dd MMM yyyy HH:mm:ss") & " +0000"
      let itemUrl = baseUrl & "/" & card.url

      rss &= "<item><title>" & escapeHtml(card.title) & "</title><link>" & itemUrl &
            "</link><pubDate>" & pubDate & "</pubDate><guid>" & itemUrl &
            "</guid><description>" & escapeHtml(card.description) & "</description></item>"

   rss &= "</channel></rss>"

   return rss

proc generateRssFile(archive: ArchiveData, outputDir: string) =
   let rssContent = generateRssFeed(archive)
   let rssPath = outputDir / "feed.xml"
   writeFile(rssPath, rssContent)
   echo fmt"Rss feed generated: {rssPath}"

proc main(inputDir: string, outputDir: string) =
   let pagesDir = outputDir / "pages"
   if not dirExists(pagesDir):
      createDir(pagesDir)

   let stoaFiles = walkStoaFiles(inputDir)
   echo fmt"Found {stoaFiles.len} .stoa files"

   var allCards: seq[BlogCard] = @[]
   for filePath in stoaFiles:
      let card = processStoaFile(filePath, pagesDir, inputDir)
      allCards.add(card)

   let archive = generateArchiveData(allCards)

   generateWebPages(archive, outputDir)
   generateRssFile(archive, outputDir)

   echo fmt"Processed {allCards.len} files."
   echo fmt"Home page cards: {archive.homeCards.len}"
   echo fmt"Tags: {archive.tagCards.len}"

when isMainModule:
   var inputDir = "stoae"
   var outputDir = "blogs"

   for kind, key, val in getopt():
      case kind
      of cmdArgument:
         discard
      of cmdLongOption, cmdShortOption:
         case key
         of "input", "i":
            inputDir = val
         of "output", "o":
            outputDir = val
         of "help", "h":
            echo "Usage: stoa [options]"
            echo "Options:"
            echo "  -i, --input   Input directory (default: stoae)"
            echo "  -o, --output  Output directory (default: blogs)"
            echo "  -h, --help    Show this help message"
            quit(0)
      of cmdEnd:
         break

   main(inputDir, outputDir)
