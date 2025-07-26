# stoa, a minimal markup language

stoa is a fully opinionated, minimal, pure text markup language.
here's my personal [blog](https://jonathanyale.github.io/pages/2025/starting_point.html) about it.

## zen of stoa

+ minimalism above all, only 47 lines of grammar.
+ works anywhere, zero editor-specific feature.
+ serve for pure & immersive reading & writing.

## full gramamr of stoa

```stoa
& inlines

= markup: `inlinecode`, |highlight|, ...
= link/ref: [url], [text | url], [#ref]

& columns

&& (nested) heading and list

= depth 1
== depth 2
=== depth 3

&& sidenotes

-- comment
|| annotation
!! warning

&& fenced blocks

|> scheme
(display "hello stoa")
|>

>>= math
∑ i = n(n+1)/2
>>=

& metadata
:: key  & value

& footnotes

invoke: [#1]
define:
#1 text

& continuation rule

= base item
  continued on same line
     any indentation preserves flow

= new paragraph with empty line(s)

  starts fresh line within block
```
