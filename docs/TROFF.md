# Troff in InferNode

A typesetting system for books: troff, written in Limbo, with its
preprocessors and macros, writing PDF to deliver and troff's own output
to read in InferNode's document views.

    book -p works.bib book.ms        # book.pdf, and book.out to view

## The parts

| Command | What it does | From |
|---|---|---|
| `troff` | Sets troff's input: paragraph-at-once filling, OpenType kerning, ligatures and features, hyphenation (English and Ancient Greek) | Neatroff, translated (byte-identical output on ~500 documents) |
| `eqn` | Mathematics: TeX's rules for setting it, in troff; Libertinus Math's sized brackets, radicals and operators (`/lib/troff/eqnrc`) | Neateqn, translated (byte-identical output) |
| `tbl` | Tables, their vertical rules only when asked (`vrules`) | Plan 9's tbl, translated (byte-identical output under `-C`) |
| `pic` | Pictures | Plan 9's pic, translated (byte-identical output; its grammar through Inferno's yacc) |
| `refer` | Citations by key from BibTeX's and refer's databases; with `-S chicago`, the *Chicago Manual of Style*'s notes and bibliography (18th edition) | Neatrefer, translated, with a BibTeX reader and styles of its own |
| `chess` | Chess diagrams from Forsyth–Edwards notation, as pictures, described in words for a tagged PDF | |
| `tr2pdf` | Troff's output as PDF: OpenType fonts embedded, subset to the glyphs used, compressed, with ToUnicode maps (text can be searched and copied) | Neatpost's PDF writer, translated |
| `mkfn` | Font descriptions for troff from OpenType, TrueType and AFM fonts, with each glyph's bounding box (CFF's too) | Neatmkfn, translated |
| `tr2img` | A page of troff's output painted as the document views paint them (its fonts, drawings and images), as a PPM image | |
| `mkindex` | A book's index from troff's output: makeindex's entries, sorted word by word as the *Chicago Manual* sorts, Greek and accents included | |
| `book2tex` | A book, article or memorandum as LaTeX: LaTeX's book and article for LuaLaTeX, or a journal's class (IEEEtran, acmart) for pdfLaTeX | |
| `book` | Runs them (with `-mbook`, or `-m article`, `-m memo` or `-m slides`): refer, pic, chess, tbl and eqn (each if there is anything for it), troff `-mbook` until its references settle, tr2pdf | |

`troff`, `eqn`, `tbl` (with `-C`), `pic`, and `refer` without a style, write what
the C programs they came from write, byte for byte, but where those
loop for ever or crash; `tr2pdf -c` and `mkfn -c` do too. Troff's, on
a device with no `sizescale`: `devutf`'s `sizescale 100` keeps sizes in
hundredths of a point (groff's scaled points), so its output's sizes are
`s1100` for 11 points, and a size an expression makes (eqn's spaces) is
not rounded to a whole point; with only whole sizes, its pages are
otherwise Neatroff's.
Without `-c` those two differ where troff and its readers are better
served (their commits list how).

Troff's output (`book.out`) opens in Xenith's document view, `wm/page`
and Lucifer: a page at a time, sharp at any zoom, its text searchable
and its links followed. A `.ms`, `.man`, `.me` or `.mm` file opens there
set by troff, beside its text, and with `Live` is set again a moment
after each edit, as Typst's preview is: see
[Writing it live](#writing-it-live).

## Writing it live

Xenith knows troff's documents once the package is in its name space
when it starts: `troffns` run from the standalone Xenith's start-up
file, `~/.infernode/usr/inferno/lib/xen/profile` on a Mac (the
README's [Xenith](../README.md#xenith) has the line, and what to do in
an older Xenith).

Execute `Live` in the tag of the window you are writing in, and Xenith
opens a window below it showing the document, which follows the text:
600 ms after the typing stops it is set again, unsaved edits and all,
where the reader was in it. `Live` again stops it. Type in the text's
window: a key typed on the document takes its window back to the text.
(If the document is already shown beside the text, a `Zerox`'d twin
`Render`ed, `Live` in either tag turns it on and off; `Render` in the
document's window goes back to the text.) A book, article or
memorandum is set by `book -l`, the whole pipeline (refer, pic, chess,
tbl, eqn, troff as often as its references need) with no PDF. A line
near the top says how:

    .\" book -m article -S numeric -p works.bib

or the line showing how it is made, as the examples have
(`.\"	book -p works.bib chapter.ms	# chapter.pdf`). With neither, a
file using `-mbook`'s headings or `.p` is set by `book -l`, one with a
`.slide` by `book -l -m slides`, and any other by troff with the
macros its name gives.

It is quick enough to write in. On one machine, from the edit's
pause to troff's output, the emulator's start included:

| document | pages | seconds |
|---|---|---|
| `examples/memo.ms` | 1 | 0.25 |
| `examples/chess.ms` | 4 | 0.25 |
| `examples/article.ms` (two columns, refer, eqn, pic, tbl) | 2 | 0.42 |
| `examples/logic.ms` | 5 | 0.55 |
| `tests/book/book.ms` (three chapters, notes, bibliography) | 21 | 0.44 |

Work on a book a chapter at a time: a chapter's file, set alone, takes
its references to other chapters from the book's `book.aux`, where the
last whole build left them, and keeps its own between edits (in
`/tmp`), so an edit is set in one pass. Not live, a document is still
set again on Put and on `doc/ctl` `refresh`.

## Writing a book: `-mbook`

Each macro is one of LaTeX's, so that a book is readily turned into
LaTeX without being LaTeX.

| `-mbook` | LaTeX |
|---|---|
| `.title`, `.subtitle`, `.author`, `.date`, `.maketitle` | `\title`, ..., `\maketitle` |
| `.frontmatter`, `.mainmatter`, `.backmatter` | the same |
| `.part "Title"` | `\part{Title}` |
| `.chapter "Title" [label] ["Short"]` | `\chapter[Short]{Title}\label{label}` |
| `.chapter* "Title"` | `\chapter*{Title}` |
| `.section "Title" [label]`, `.subsection`, `.subsubsection` | `\section`, `\subsection`, `\subsubsection` |
| `.list 1` (or `a`, `i`) ... `.item` ... `.endlist` | `enumerate` with `\item` |
| `.list` (or `bullet`, `dash`) ... `.item` ... `.endlist` | `itemize` with `\item` |
| `.image file [width [height]]` | `\includegraphics[width=...,height=...]{file}` |
| a blank line, or `.p` | a paragraph |
| `.quote` ... `.endquote` | `quotation` |
| `.epigraph` ... `.attrib "Source"` `.endepigraph` | `\epigraph{...}{Source}` |
| `text\*[fnmark]` then `.fn` ... `.fe` | `\footnote{...}` |
| `text\*[enmark]` then `.en` ... `.ee`; `.notes` | `\endnote{...}`; `\theendnotes` |
| `.label name`; `\*[ref name]`, `\*[pageref name]` | `\label`, `\ref`, `\pageref` |
| `\*[TeX]`, `\*[LaTeX]` (their logos, in the text or a heading; `-ms` too) | `\TeX{}`, `\LaTeX{}` |
| `.url address [after]`, `.link address "text" [after]` | `\url{address}`, `\href{address}{text}` (IEEEtran: `text (\url{address})`) |
| `.appendix` | `\appendix` (IEEEtran: `\appendices`) |
| `.contents` | `\tableofcontents` |
| `.cite key [loc][; key loc]` | `\autocite[loc]{key}` (biblatex-chicago) |
| `\*[cite key loc]` within a note of one's own | `\cite[loc]{key}` |
| `.bibliography` | `\printbibliography` |
| `.index "term!sub"` | `\index{term!sub}` (makeindex's syntax) |
| `.printindex` | `\printindex` |
| `$...$` (after `delim $$`) | `$...$` |
| `.EQ` ... `.EN`; `.EQ (1.1)` | `\[...\]`; `equation` with `\tag{1.1}` |
| `.TS` ... `.TE` | `tabular` (in a `table`) |
| `.PS` ... `.PE` | `picture` (or TikZ) |
| `.figure [label]` ... `.caption "Text"` `.endfigure` | `figure` with `\caption` and `\label` |
| `.table [label]` ... `.caption "Text"` `.endtable` | `table` with `\caption` and `\label` |
| `.listoffigures`, `.listoftables` | `\listoffigures`, `\listoftables` |
| `\fI...\fP`, `\fB...\fP` | `\emph{...}`, `\textbf{...}` |

A footnote's mark follows the text before it: end that line with `\c`
(or put `\*[fnmark]` where the mark goes) and begin the next with `.fn`.
`refer`'s citing notes do this themselves.

The page is 6 by 9 inches, set in 11-point Libertinus on 14 points;
change it before the first text:

    .papersize 8.5i 11i
    .margins 1i 1i 1.25i 1i          \" top bottom inner outer
    .nr book-ps 12                   \" point size, whole points
    .nr book-vs 15p
    .nr book-recto 0                 \" chapters need not open on the right
    .ds book-citenotes en            \" citing notes as endnotes

Chapters open on right-hand pages, with no running head and their folio
at the foot; the running heads are the book's title on the left, the
chapter's on the right. A numbered chapter's sections are numbered in
it (1.1, 1.1.1), in their headings as in the contents and references,
as LaTeX's book class numbers them; those of the front matter and of an
unnumbered chapter are not. Footnotes are numbered in each chapter.
Endnotes are gathered under their chapters' names for `.notes`.

Footnotes are set at the foot of their marks' pages, in order:
- A note too long for the room left is begun there if three of its
  lines fit, and goes on at the next page's foot, as LaTeX splits a
  note. A shorter note that doesn't fit goes whole to the next page.
- troff fills a paragraph at once, so a mark may be several lines into
  text not yet set. `.fe` counts those lines (troff's `.pend` register).
- The page's foot sets only the notes whose marks went out on it.
  troff learns which as each line goes out (an `\X'nr fn-out N'` in the
  mark): a line the widows' rule moved on takes its note with it.

The table of contents and the references need a second pass (the pages
are known only once the book has been set): `book` gathers what the
first pass learnt (the `aux:` lines troff writes to its standard error)
into `book.aux`, and sets the book again until it no longer changes.

## Drafts and the book as it goes to press: `book -f`

`book` sets a draft; `book -f` sets the book as it goes to press, with
microtypography, as LaTeX's microtype (with pdfTeX) sets a book:
punctuation, hyphens, quotation marks and a few letters hang into the
margins (*protrusion*), so that the text's edges look straight rather
than measure straight; and a justified line's glyphs widen or narrow by
up to 2% (*expansion*), so that its spaces vary less from line to line.
A paragraph is filled knowing both, so its lines break better too.

It is troff's (`-mbook` turns it on when the register `book-final` is
set, as `book -f` sets it):

    .mtpc R 0 700 . \(hy         \" font R: these hang right by 0.7 of their width
    .mtpc R 500 300 “            \" left by half, right by 0.3
    .mtp 1                       \" protrusion on, in this environment
    .mte 20 20 5                 \" expansion: stretch, shrink, step (thousandths)

The codes are in thousandths of each glyph's width, as pdfTeX's
`\lpcode` and `\rpcode`; `-mbook`'s follow microtype's defaults. A
line's first glyph protrudes left, its last (or the hyphen inserted)
right; a first line indented by `.ti` (a paragraph's) does not protrude
left.

Expansion treats a line's glyphs as giving like its spaces: the line's
lack or excess is divided between them as their give divides it (as
pdfTeX's), the glyphs' share rounded to a step. troff scales the glyphs'
advances, and says by how much (`x X mtx 15`, thousandths) for tr2pdf,
which draws their shapes as scaled (`Tz`), each where troff put it.
With `.mtp 0` and `.mte 0`, the defaults, troff sets as C Neatroff does.

## Lines: a paragraph broken whole

`-mbook` breaks a paragraph into lines as TeX does, choosing all its
breaks at once, and lets a line's spaces shrink as well as stretch, so a
line need not be broken short and stretched to the margin:

    .ad pb                       \" justified, each paragraph's breaks chosen whole
    .ssh 33                      \" a space may shrink by a third, as TeX's may
    .hycost 300 3000             \" a hyphen costs as a loose line; a second in a row, ten times
    .hlm 3                       \" never four in a row
    .ss 12 0                     \" one space after a sentence, not two

Each environment has its own (the text, the notes, quotations), so
`book-fill` sets them in each. Measured on 180 pages of this tree's
prose (`docs/*.md`), set as `book -f` sets it and by LuaLaTeX with
microtype:

| | mean space | 95th percentile | lines looser than 0.5 em | lines hyphenated | two in a row |
|---|---|---|---|---|---|
| line by line (`.ad b`), as before | 0.34 em | 0.48 em | 137 | 30% | 333 |
| as now | 0.27 em | 0.38 em | 21 | 10% | 32 |
| LuaLaTeX, microtype | 0.28 em | 0.35 em | 25 | 8% | 28 |

Line by line, troff could break only where the words fitted, never
shrink, so its spaces stretched by half on average and nearly a third
of its lines ended in a hyphen. Whole paragraphs cost little time: a
book of 444 pages with notes on every page took 3% longer, and came to
431 pages.

## Widows and orphans: `.wo`

A paragraph is broken by a page only with two lines at least on either
side: its first line is not left alone at a page's foot (an orphan), nor
its last carried alone to the next page's head (a widow), as LaTeX's
penalties keep them. Where one would be, a line more goes with it to
the next page and this one is a line short, or the whole paragraph goes.
troff does it (`.wo 1`, in an environment) as it fills: the page's last
lines are set only when what follows them is known, and a note that
moves the foot up is allowed for. `-mbook` sets it in drafts as in the
book as it goes to press, so the two break their pages alike. With
`.wo 0`, the default, troff sets as C Neatroff does.

## Pages flush at the foot

Keeping a heading with its text, or a widow or orphan from a page,
leaves the page a line or more short. LaTeX's book class sets every
page's text to end at the same place (`\flushbottom`), spreading what a
page lacks through it; `-mbook` does the same through tr2pdf. The
macros say where space may stretch, and where a page's text ends and a
full page's would:

    x X vstretch 100             \" the space after this line may stretch, by 1 point (weight)
    x X vfoot 58600 1400         \" the text ends; a full page's last baseline, its spacing

`-mbook` marks the space between paragraphs (1 point), before a section
(4) and a subsection (3), after a heading (1), and about quotations,
epigraphs, displayed equations, tables and pictures (3). A page's lack
goes to those points first, each taking as much as its weight in
proportion; then to its lines, a seventh of their spacing each at
most; anything left goes to the points again, beyond their weights, as
TeX gives what its glue cannot stretch to the glue that stretches. A
gap's space goes to what is set below its middle, after it: not to a
subscript of the line above, nor to a table's rule under its last row.
A picture, a displayed equation and a table move whole: their rows are
not lines to stretch between. What follows the text (notes, the folio,
the running heads) stays where it was set, and links, destinations and
bookmarks move with the text.

A preprocessor that sets a title over its display keeps them together
with the register `book-keep`: set, the next display's space above it
does not stretch (`wwb/tableau` sets it over its countermodels' tables). A chapter's last page, a page broken by `.bp`, one set in
columns or short by more than five lines stays as set. Of a book of 444
pages, those ending short went from 47% to 27%, all chapters' ends, as
LaTeX's 26%.

tr2pdf writes each page's vertical places as placeholders and gives
them at its end, so a page's plan costs nothing until it is known.

## The index: `.index` and `mkindex`

An entry is written as LaTeX's `\index` (makeindex's syntax), on a line
of its own before the line its word begins:

    .index "virtue"
    virtue is ...
    .index "virtue!and justice"           \" a subentry (up to three levels)
    .index "aretē@ἀρετή"                  \" sorted as aretē, set as ἀρετή
    .index "polis|see{city}"
    .index "Plato|seealso{Socrates}"
    .index "tragedy|("  ...  .index "tragedy|)"   \" a range
    .index "soul|textbf"                  \" its page in bold (textit, emph)

`.index` puts the entry into troff's output where the word after it is
set (`x X idx`), so it gives that page even when the line or its note
goes to the next; each page's foot writes its folio (`x X folio`).
`mkindex book.out` reads them back and writes the index for
`.printindex`, which sets it in two columns at the end of the book.
The order is the *Manual*'s, word by word (New York before Newark), case,
accents, breathings and troff's escapes aside (Ætna and ἀρετή under a);
three pages or more in a row are a range, a range's end abbreviated as
the *Manual* abbreviates it (101–8); a page is given once, in bold or
italic if any entry on it asks; *See also* follows an entry's
subentries. `book` runs `mkindex` after each pass and sets the book
again until the index, too, no longer changes.

## Reading it on a screen: links and bookmarks

The PDF is made to be read as well as printed, as hyperref makes
LaTeX's:
- **Links.** These are links to where they lead:
  - each line of the contents;
  - `\*[ref]` and `\*[pageref]`;
  - a footnote's or endnote's mark (and the note's number, back to the
    mark);
  - each page in the index.
- **Bookmarks.** The bookmarks are the contents: parts, chapters and
  sections, each under the one it is in.
- **Page labels.** Each page is labelled as it is numbered, so a viewer
  shows iv, not 4.
- **Information.** `.title` and `.author` become the PDF's information.

The macros put destinations and bookmarks where their headings, labels
and notes are set (`x X dest name`, `x X outline level title`), and
links on text (`x X link #name width height`). tr2pdf takes the page
and the place from where they land: a heading is found wherever troff
put it. Each page's folio (`x X folio`) gives its label and its
destination for the index (`pg-` and the folio). `mkindex -l`, as
`book` runs it, writes each page as a link (`\*[book-pl folio shown]`).

## Heard as well as read: a tagged PDF (PDF/UA-1)

`book`'s PDF is tagged, for those who hear it read (a screen reader) or
have it reflowed: its structure is the book's, in reading order, and it
claims PDF/UA-1 (ISO 14289-1). veraPDF finds it conforms.
- **Structure.** The title page, headings (`H1` for the title, each
  chapter, the contents, notes, bibliography and index; `H2` and `H3`
  for sections), paragraphs, quotations and epigraphs (`BlockQuote`),
  footnotes and endnotes (`Note`, each with its ID, a note continued on
  the next page one note), the contents (`TOC`, each line a `TOCI`),
  the bibliography's entries, the index (`Index`).
- **Equations.** Each a `Formula`, described in words as a screen
  reader would speak it (`x sup 2 + y sub i sup 2` is "x squared plus
  y sub i squared"; `{-b +- sqrt {b sup 2 - 4ac}} over 2a` "the
  fraction with numerator minus b plus or minus the square root of b
  squared minus 4 a c, end root, and denominator 2 a"; limits,
  integrals, functions, cases and matrices read as ClearSpeak reads
  them), `set speech 1` in eqnrc; without it, by its eqn as written.
  A display is a block of its own.
- **Tables.** Each a `Table` of rows (`TR`) of cells (`TD`); the rows
  above the first rule, if rows follow it, headings (`TH`, `Scope`); a
  cell spanning columns says so (`ColSpan`); a text block (`T{ T}`) is
  its cell's.
- **Pictures.** Each a `Figure`, described by `.alt "text"` before
  `.PS`. One with none is said (`book: a picture with no .alt`), and the
  PDF is tagged but no longer claims PDF/UA: what a picture shows is
  for its author to say.
- **Links.** Each a `Link` element, its annotation its object, described
  by the text it is on (`1.1 The Argument of the Good 2`).
- **Not read.** Running heads, folios, the notes' rule, a table's
  rules: artifacts.
- **Language and title.** `en`, or the string `book-lang`; the title
  shown as the window's, and in the metadata (XMP).

The tags are troff's device controls, as the links are: `x X tag P`
begins a paragraph, `x X tag push Note fn-3` a note in it, `x X tag
pop` ends it (tr2pdf(1) has them all). `-mbook` gives them with
`.dv` once the text before has gone out, after a break; in a diversion
(a note waiting for its page's foot, the endnotes gathered, the index
before it is set in columns) the tag is kept there (`\!`) and given
when the diversion goes out, so a tag lands where its text is set, not
where it was written. eqn and tbl, given `-t` (as `book` gives it),
put theirs inline (`\X`), in the line with the equation or the row.
Without it their output stays Neateqn's and Plan 9's, byte for byte.

tr2pdf builds the structure tree from them, marks each glyph and line
with its element's MCID (or as an artifact) and writes the parent tree,
the IDs' tree, `MarkInfo`, `Lang`, `DisplayDocTitle` and the metadata.
Marked content is kept out of text objects: tr2pdf now begins a text
object (`BT`) when text is set and ends it for what is drawn, where
Neatpost drew within one. troff's output with no `x X tag` is a PDF
with no structure, as before; `-c` writes Neatpost's whatever it is
given.

Where a note falls: a note is set at its page's foot, so it is in the
structure where its paragraph was when the foot came, a `Note` inside
that `P`. `-ms` and `-man`
documents are not yet tagged; their equations and tables are, through
`eqn -t` and `tbl -t`.

`tests/host/tagged_test.sh` checks a book's structure, its marking and
parent tree, its links' descriptions, and (where veraPDF is) PDF/UA-1.

## Citations: `refer -S chicago`

Works are cited by their keys, from a BibTeX database (`works.bib`) or
refer's. The first citation of a work in a chapter is its full note,
later ones the short note; up to three authors are named in a note (the
first and *et al.* past that), up to six in the bibliography (three and
*et al.* past that); page ranges are abbreviated as the Manual
abbreviates them (101–8, 321–28, 1496–1504). The bibliography is in the
Manual's order: by the first author's name; a work by that author alone
before those written with others, and those by the others' names, in
order; then by title. Kinds of work: books
(author, editor or both, translator, edition, volume, series), chapters
in edited books, articles (with DOIs), theses, other works, and
classical works cited by their parts (`entrysubtype = {classical}`:
Homer, *Iliad* 1.1–5). See `appl/cmd/refer/style/chicago.b` for its
rules and `tests/refer/` for examples.

An article or a chapter cited whole is given its pages the first time,
a chapter its number (*chap. 2 in*), a month its name, as
biblatex-chicago gives them. Options follow the style's name, as
biblatex's do (`book -S chicago,british,nodoi`):

| Option | |
|---|---|
| `british` | titles in single quotation marks, quotations within them double, the punctuation after the marks (biblatex with British English) |
| `nodoi` | no DOI (biblatex's `doi=false`) |
| `nourl` | no URL (`url=false`) |

A style is a module (`module/referstyle.m`): another is a file of its
own under `appl/cmd/refer/style`.

## Mathematics: `eqn`

Equations are written in eqn's language (Kernighan and Cherry's, with
groff's additions), and set by TeX's rules:

    .EQ
    delim $$
    .EN
    The roots of $a x sup 2 + b x + c = 0$ are
    .EQ (1.1)
    x = {- b +- sqrt {b sup 2 - 4ac}} over {2a}
    .EN

`book` runs eqn when a book has equations, after
`/lib/troff/eqnrc`: its settings for Libertinus Math (by hand, `eqn
/lib/troff/eqnrc - <doc`: eqn reads the files it is given in order, `-`
its standard input, where Neateqn read only its standard input and
ignored a file named). Brackets (`left (`
... `right )`) take the font's larger sizes, then are built from its
pieces; radicals likewise; a displayed sum, product or integral is the
font's display size, an inline one the text size with its limits beside
it (`ifdisplay` and `set text_limits 1`, which eqn has beyond Neateqn).
A display is centred, its label at the right on its baseline.

eqnrc gives eqn Libertinus Math's own parameters, from the font's MATH
table, where TeX's for Computer Modern were: scripts 80% of the text's
size and their scripts 60% (`set script_percent_scale_down`, beyond
Neateqn: it made each 7/10 of the one above, a superscript of 11 points
7), the shifts of superscripts and subscripts, fractions' numerators and
denominators, the axis, rules and the gaps about a sum's limits. The
names of functions (`sin`, `cos`, `log`, `lim` ...) are operators, as
TeX's: `a cos theta` is set with a thin space between `a` and `cos`, not
as `acos`. An integral's limits are beside it, as TeX sets them
(`nolimits`, beyond Neateqn), and `book2tex` writes `\int_0^\infty`, not
`\int\limits`.
A superscript on a letter is raised from the letter's baseline, not
from its top less a drop, as TeX's rule 18a has it (`set
tex_script_drop 1`); a fraction's numerator and denominator keep the
font's gaps from its bar, larger in a display (`set fraction_gap` and
`set fraction_display_gap`).

Set against XeLaTeX (`unicode-math`, Libertinus Math, 11 points) on
displays known to be hard (`tests/eqn/hard.ms`: continued fractions,
nested and indexed radicals, Euler–Maclaurin, Vandermonde and Hessian
matrices, cases, aligned systems, braces, towers of scripts), eqnrc's
settings put each part where TeX puts it, to a fraction of a point:
matrices as TeX's arrays, each column its own width and each row its
own height (`set tex_arrays 1`); scripts within the font's limits
(`set sub_superscript_gap_min` and the rest); an integral's lower limit
under its tail by its italic correction (`type op icorr`); fractions'
parts in TeX's styles (`set tex_fractions 1`), so a fraction in an
exponent is in scriptscript size, `displaystyle` for `\dfrac` and
`\cfrac`; `{}` an ordinary atom, as TeX's (`set tex_atoms 1`); capital
Greek upright; letters in the font's maths italic, 𝑥 not *x*, with
their italic correction before a parenthesis (`set math_italic 1`);
accents the font's glyphs on each letter's top accent attachment, wider
variants over more (`set tex_accents 1`, `accent`, `accentpos`), `bar`
over one letter a macron, as `\bar`; delimiters' first sizes the math
font's, as TeX's; operators and relations from the math font (`gsfont S`);
radicals by the font's gaps, and `root n x` for an indexed one;
`overbrace` and `underbrace`, the font's sizes or pieces; `n choose k`
as `\binom` (the font's stack shifts, parentheses of TeX's delim1 and
delim2); `strut` as `\strut`, so that a continued fraction written with
one in each numerator is spaced as `\cfrac`'s; delimiters as
TeX sizes them (`set delimiter_factor 901`). Its scripts are TeX's 8.8
points and scriptscripts 6.6 (`set scaled_sizes 1`: the device's
`sizescale 100` keeps sizes in hundredths of a point, as groff's scaled
points). A page of hard displays (`examples/maths.ms`) is built whole in 0.5
seconds by `book -f`, emu's start included, by XeLaTeX in 1.9 and by
LuaLaTeX in 3.8 (two passes each, font caches warm). At a book's length
of mathematics XeLaTeX and LuaLaTeX are faster (see Speed).
In running text and between displays (`tests/eqn/text.ms`, set beside
XeLaTeX's of `book2tex`'s LaTeX): an operator's limits are beside it in
text (`lim` too: eqnrc's function names are braced, so that `from`
finds an operator); displays lined up (eqn's `lineup`) are TeX's `\jot`
apart, as `align`'s lines, and indented as the one with the `mark`, so
that eqn's motion to the mark puts their signs one above the other; a
display after a paragraph's line ending two ems short of it has less
space above and below it, as TeX's `\abovedisplayshortskip` and
`\belowdisplayshortskip` (troff's `\n[.n]`, classic troff's register,
the text's length on the line set last, tells). `tests/host/mathtext_test.sh`
checks these.

What is the font's in all this is its MATH table's: `mkfn -M` writes
it as eqn's settings (constants, maths italic glyphs and their italic
corrections and accent attachments, accents, delimiters' and braces'
sizes and pieces, big operators), and `/lib/troff/eqnrc` holds what it
writes for Libertinus Math after TeX's own rules. Another OpenType math
font is the same two commands (`mkfn -M`, and its description as S):
Latin Modern Math, set so, puts the 23 displays where XeLaTeX with
`\setmathfont{Latin Modern Math}` puts them.
`tests/host/maths_test.sh` checks each against TeX's placement;
`tests/host/sizescale_test.sh` checks troff's scaled sizes.

Glyphs' heights and depths come from the fonts' descriptions: `mkfn`
reads each glyph's bounding box from its outline, CFF's (Libertinus's)
as well as TrueType's.

## Tables and pictures: `tbl` and `pic`

Tables are written in tbl's language, pictures in pic's (Lesk's and
Kernighan's); `book` runs each when a book has any. Under `-mbook` a
table's rules, and an equation's (its fractions', radicals', bars and
underlines), are drawn as lines, and a picture is centred with space
about it.

A table's horizontal rules are drawn and its vertical ones are not:
no `|` between columns, no sides to a `box`, as the style manuals ask
(Chicago's, APA's, the IEEE's, booktabs'). The room for them between
the columns is kept. A table that wants them asks with the option
`vrules` (`box vrules;`); `tbl -C` draws every one, as Bell's tbl did,
and writes Plan 9's tbl's output byte for byte.

The rules come from troff's `.rules`, on for every document (`.rules 0`
sets Neatroff's glyphs again). It draws `\l`'s and `\L`'s of
rule characters as lines, not as a font's glyphs set side by side,
which leave joins and are copied with the text. Each line is a filled
rectangle exactly where the glyphs' ink would be. Its place and
thickness come from the glyph's bounding box: the character's own, or
the one its `.char` gives it (eqnrc's rules are Libertinus Math's).
eqn and tbl place the rules by those boxes, so each lands where its
glyphs would have.

## Chess: `chess`

`chess` sets each board between `.CB` and `.CE`; `book` runs it before
pic when a book has one. The position is given in Forsyth–Edwards
notation (`fen`, with `w` or `b` for the side to move). `size` sets the
board's side in inches (2 by default), `flip` turns it so that Black
is at the foot, and `nocoords` leaves out the files and ranks named
along its edges.

A board is written the way pic writes a picture: `.PS` with its height
and width, the drawing, `.PE`. `-mbook` places it as it places a
picture: centred, kept on one page, tagged as a Figure. The drawing is
troff's: each dark square a filled polygon in grey (`\D'P'`), the edge
a polygon, each piece a glyph centred on its square. Nothing is left
for a later program, so tr2pdf, tr2img and the document views show the
same board.

The pieces are the Unicode chess figures (U+2654 to U+265F) in `CH`, a
special font `-mbook` mounts: a 14 KB subset of Noto Sans Symbols 2,
under the OFL, renamed to mark it as modified
(`fonts/chess/NOTICE`). DejaVu Sans was tried first. Its white king and
bishop have their heads filled, so they read as black pieces on a dark
square. A white piece is two glyphs: the black figure in white, then
the outline over it. Without the white fill, a dark square's grey shows
through the outline and the piece is hard to read.

A Figure in a tagged PDF must be described. Unless `.alt` gives a
description, `chess` writes one from the position, each side's pieces
by kind, then the side to move: "Chess diagram. White: King d6, Queen
h1. Black: King d8, Rook c2. White to move." A screen reader then says
what a sighted reader sees.

A position that is not eight ranks of eight squares, a letter that is
not a piece, an unknown setting and a board with no `.CE` are reported
with the file and line, and `chess` fails. Lines are kept in step for
troff (`.lf`), so troff's own messages name the right line.
`tests/host/chess_test.sh` checks all of it, and that tr2img paints
the board.

## A thesis: the page, the notes, lists and images

A doctoral dissertation written for XeLaTeX (A4, 12 points double
spaced, notes in Chicago's style by biblatex, figures, 230 pages) was
set with `-mbook` from its LaTeX, on the same page in the same face, to
find what a real manuscript asks. Its chapters came out page for page
as XeLaTeX sets them, in 12 seconds against XeLaTeX's 43 and LuaLaTeX's
63 (each three passes and biber; README, Benchmarks). What it asked for:

    .papersize a4                \" or a5, b5, letter; a size no page could be is refused
    .nr book-recto 0             \" one-sided: a chapter on the next page
    .nr book-ps 12               \" 12 points,
    .nr book-vs 24p              \" double spaced,
    .nr book-nps 10              \" its notes 10 points,
    .nr book-nvs 12p             \" single spaced,
    .nr book-tvs 14p             \" and its contents single spaced
    .chapter "A Long Title" ch3 "Short"   \" Short its running head
    .subsubsection "Title"       \" not numbered, not in the contents
    .list 1                      \" or a, i, bullet, dash; lists nest
    .item
    The first.
    .endlist
    .alt "What the figure shows"
    .image fig.jpg 5i 1.9i       \" a JPEG or a PNG, its width and height
    .image plot.pdf 4i           \" a PDF's first page, in vectors

A note within a note (`.fn` ... `.fe` inside one, as LaTeX's `\footnote`
may be) is numbered after it, its mark in it, and set below it.
A note's number is set full size and hung in the margin, the note's
text at the text's margin, as Bringhurst sets them (`book-fnhang 0`
raises it at the note's head instead). A word breaks with three
letters at least after its hyphen. Long entries in the contents are
filled short of their page's number and hung after their numbers,
subsections further in than sections, as LaTeX sets them; a running
head too long to sit beside its page's number is said, and the
chapter's number set instead. `tr2pdf` places images (`x X image file
w h`), and the document views paint them there (`tr2img` one page): a JPEG's data as it is, a PNG decoded, its alpha a soft mask, its
palette an indexed colour space; a PDF's first page a form, its
vectors and fonts as they were (pdfTeX's, LuaTeX's and Ghostscript's
compressed object streams read); tagged, each is a Figure described by
`.alt`. Two registers set a thesis as LaTeX's book class does by
default: `book-plain` 1, no running heads and every page's number
centred at its foot; `book-chlatex` 1, a chapter headed by
"Chapter N" and its title below, both bold and at the left, at
LaTeX's sizes for the text's (`\huge`, `\Huge`) and LaTeX's distances,
stretched as the text's lines are from single spacing (`book-tvs`), and
its line in the contents bold, its number with no stop, no leaders. For a
one-sided thesis, `book-oneside` 1 puts the binding margin on the left
of every page and heads every page with its chapter, its number at the
right (LaTeX's `oneside`); `.ds book-adj pl` sets the text ragged
right, its lines still broken a paragraph at a time.
`tests/host/manuscript_test.sh` checks each of these.

## Figures and tables that float

A picture or table may be put in a figure or a table, with a caption,
to be set where it fits, as LaTeX's environments are:

    .figure flow                 \" a figure, labelled flow
    .alt "Three boxes joined by arrows"
    .PS
    box "read"; arrow; box "parse"; arrow; box "set"
    .PE
    .caption "How a document flows."
    .endfigure

The caption is numbered in its chapter (Figure 3.2, Table 3.1; in the
order written), and set below what it follows or above what it
precedes: a table's usually first. `\*[ref flow]` is its number,
`\*[pageref flow]` the page it is set on. `.listoffigures` and
`.listoftables` list them, each entry a link to its caption.

What is between `.figure` and `.endfigure` is set in an environment of
its own, so a figure written in a paragraph leaves the paragraph whole.
It is set where it is written if nothing is waiting and it fits there,
between paragraphs; written in a paragraph, after the paragraph if it
fits then (as near to LaTeX's `[h]` as a paragraph not broken for it
can be); otherwise it waits for the top of the next page,
where as many as take seven tenths of the page are set, the first
whatever its size, in their order. Any still waiting when a chapter
ends are set before it ends. On a test of four figures and a table,
LaTeX set each on the same page but one, which troff set a page later.

Tagged, each is a `Div` of its `Caption` and its `Figure` or `Table`.
`book2tex` writes `figure` and `table` (`[tbp]`, `\centering`) with
their `\caption` and `\label`.
`tests/host/floats_test.sh` checks each of these, and the LaTeX set by
LuaLaTeX where it is installed.

## Articles and memoranda: `-marticle` and `-mmemo`

Two classes are built on `-mbook`'s macros, so that an article or a
memorandum has what a book has (notes, floats, equations, citations,
cross-references, the tagged PDF) set as such a document is set.
`book -m article` and `book -m memo` run them.

`-marticle` is a journal's article, after LaTeX's article class with
`twocolumn`: letter paper (`.papersize a4` for A4), 10 points on 12,
three-quarter-inch margins, the columns a fifth of an inch apart. Its
title, authors (`.author`, `.affil`, `.email`, three to a row) and
abstract are set across the page at the head of the first; then the
text, in two columns (`.columns 1` for one, its margins wider so that
its measure is about 75 characters). Sections are numbered without a
chapter's number (1, 1.1), `.section*` is unnumbered, and the
references are a section at the end. `.figure*` and `.table*` are set
across both columns, at the top of a page after the one they are
written on, as LaTeX's `figure*` is.

Columns are -mbook's, made general. A page's columns are traps: when
the first column's foot is reached, its notes are set below it, the
page offset moves by a column and the gutter, and the second begins at
the columns' top, with its own notes planned and its floats placed.
Each column ends flush at its foot, as LaTeX's two-column articles do:
tr2pdf's vertical stretching works by regions, each column one (`x X
vcol` begins one, `x X vfoot` says where it would end were it full), so
each is stretched to its own foot, and what is set above the columns
(the title, a figure across them) stays where it is. A section's
heading is kept with two lines of its text, no more.

The last page's columns are balanced. Its text's height is not known
until it has been set, so it is recorded, at the end, in the file of
cross-references `book` already reads on its next pass; on that pass
the last page's first column ends at half that height, in whole lines.
The height is measured once, on the page as set unbalanced, and kept:
measured again on the balanced page it would differ by a line, and the
passes would not settle.

`-mmemo` is a technical memorandum, headed as Bell Laboratories' were:
the subject at the left, with the case and file it is charged to; the
date, the authors (each with a room and an extension) and the
memorandum's number at the right, each label in italics in the margin
of its block; the kind (`MEMORANDUM FOR FILE`) across the page below;
then the text in one column. `.kind report` heads it as a report
instead, its title centred. `.signature` sets the authors' names at the
end.

Journals cite by number, not in notes: `refer -S numeric` sets `[1]` in
the line, before the punctuation the line ends with (`found it [1].`),
`[1, p. 5]` at a page, `[1], [3]` for two; the works are numbered in
the order they are first cited, and the references are in that order,
each hung from its number, its authors by their initials (B. W.
Kernighan), its article's title in quotation marks and its journal in
italics, with volume, number and pages. A style says whether it cites
in the line (`inline` in `module/referstyle.m`), and the label an entry
hangs from; `.]be` hangs it.

The classes found a gap in troff: `.if d name`, true when a string,
macro or diversion is defined, as in groff and Plan 9's troff, was
missing from this troff, and was read as a comparison of strings
delimited by `d`. It is there now.

`examples/article.ms` and `examples/memo.ms` are set so, and
`tests/host/article_test.sh` checks them, and an article of six pages
generated with notes and figures in both columns and across them: no
word overlapping another, the columns flush and the last page balanced.

## Slides: `-mslides`

A third class on `-mbook`'s macros sets a talk, after LaTeX's beamer:
a page a slide, 10 by 5.625 inches (16:9; `.aspect 4:3` for 10 by
7.5), 20 points on 25, Libertinus Sans (`.typeface serif` for the
book's face), the text ragged and not hyphenated, titles in a dark
blue (`.accent`), the slide's number small at the foot's right. What a
book sets in a page a slide sets: lists, equations, tables, pictures,
images, boards, links. `book -m slides` runs it, citing by number:
there is no foot for notes, and `.fn` is refused.

Everything rests on one choice: a slide is diverted whole and set when
the next begins. Then it is known before any of it is set, and three
things a slide wants come of that.

*Builds.* Each `.pause` ends the slide's diversion and begins another,
so a slide of three steps is three diversions. Its first page sets the
first, its second the first two, and so on; what was shown already is
where it was, because what comes after is below it (beamer's `\pause`
leaves the later parts' room, invisible, for the same reason). A
diversion is set again as often as it is wanted, so the source is read
once. The pages share the slide's number, as their folio and so as the
PDF's page labels (3, 3, 3).

The tagged PDF must read the slide once. The pages before its last are
artifacts (`x X tag art`), and tr2pdf now takes an artifact as outside
the structure: a tag within one is not made, so the list items and
paragraphs that page repeats are not elements, and neither is a link,
which PDF/UA wants in the structure. The slide's last page has its
structure, a `Sect` holding its heading (H2, or H3 under a section's)
and its text, and its links; a `.label` in a slide is a destination
there too, written by a transparent line (`\!.sl-dest`) that only the
last page's setting turns into `x X dest`, as a destination's name may
be given once. The slide's own destination and bookmark are on its
first page, where one going to the slide should arrive.

*Overflow.* A slide's height is known before it is set: on its last
page, where its last step's last line reaches is compared with the
foot, and a slide too tall is said with by how much, in points. Its
text then runs off the page, as beamer's does, not onto another: while
a slide is set, troff's page is made as long as it needs, and the
PDF's page is `x X papersize`'s, which clips it.

*Columns.* `.column` diverts each column within the slide's diversion
(the column's measure `-mbook`'s, so a display is centred in it); at
`.endcolumns` each is set from the place they began, one beside
another, and the text goes on below the longest. A `.pause` within
columns would split a column's diversion across steps, and is refused.

An image is `-mbook`'s `.image`, with two differences. Its room is
made even where a slide or a column begins, which no-space mode (so
that a slide does not open with space) would otherwise swallow: the
image was set upward from the first baseline, over the title. And an
image given no size is its own, no wider than the line and no taller
than the room below it, reckoned from where the slide's text begins
(below a title of one line), the steps before and the place in the
step, so that a photograph dropped onto a slide fits it.

The slide's pages are laid out by place, not by traps: the title from
the top margin, the text below it, the folio half way down the bottom
margin; `-mbook`'s head is reduced to setting the page's size and
offset, and its end (notes and floats waiting) is not wanted. A float
is set where it is written: a slide has nowhere else for it.

It found a fault in troff. A diversion reread into another gave each
line the spacing of the environment it was reread in, not its own: a
program's text on a tint, set at 16 points on 21 and diverted again as
part of its slide, came out at 25. Each line keeps its own now
(`ren_sp` records the spacing the line was given, not the
environment's). And a place given by `|` and an expression,
`.sp |\n[.p]u*30/100u`, is not that expression's value: the page broke
there. The class reckons such a place into a register first.

A title with an apostrophe broke more than slides. `-mbook` tested
strings for text by comparing them with nothing (`'\*[x]''`) and
measured running heads and captions with `\w'...'`, and set the heads
with `.tl '...'`: an apostrophe in the string ends the comparison, the
measure or the field. A caption such as "Gauss's box" printed troff's
requests as text, and a chapter "Gauss's Law of Error" lost its running
head. Text is now tested by its width (`\w^\*[x]^`), measured with `^`
as the delimiter, and the heads set with `"`, in `-mbook`, `-marticle`,
`-mmemo` and `-mslides`.

`examples/slides.ms` is a talk of eleven slides on fifteen pages, and
`tests/host/slides_test.sh` checks it: the steps, each page the one
before with more and nothing moved; the labels, the structure each
slide's once and the bookmarks; columns and a display in one; the
references; a slide too tall said and run off its page; a link on a
slide with steps made on its last page alone; images first on a slide
and in a column, in a figure, fitted when given no size, and arriving
with a step; apostrophes in titles, a caption and a chapter's running
head.

## Fonts

The device `utf` (`lib/troff/devutf`) sets in Libertinus: Serif (R, I,
B, BI), Sans (HR, HI, HB), Mono (CR), Math (S), with Greek. Its
descriptions are made by `mkfn` (`lib/troff/devutf/mkdesc`). Another
font, Minion Pro for one, is described the same way:

    mkfn -b -l -o -r7200 -Slatn,grek -tMR -f/fonts/minion/MinionPro-Regular.otf /fonts/minion/MinionPro-Regular.otf >/lib/troff/devutf/MR

Glyphs beyond U+FFFF (mathematical alphanumerics, for one) are
described without names: a Limbo string's characters are 16 bits.

A character none of Libertinus's fonts has (✓, ☐, many symbols) is set
in the fallback, DejaVu Sans (`DF`, a special font `-mbook` mounts: troff
looks for a glyph in it when the font set in lacks one). One no font has
is said (`troff: no font has 中 (U+4E2D)`), once, where C Neatroff drops
it without a word (`.mg 1`, as `-mbook` sets it).

A pair is kerned as its font kerns it, once. Libertinus's Latin and
Greek share their kerning lookups. Neatmkfn wrote a lookup once for
each script, and troff, with no script chosen, performed every copy:
every pair in every book set before this was kerned twice (AV by -224
units at 10 points, not the font's -112). Neatmkfn also left out the
pairs a kerning class table gives its first glyphs' class 0 (D in DA,
DV and DY). `mkfn` now writes a shared lookup once, with no script,
and class 0 as every glyph of the table's coverage given no other
class. `tests/host/troff_test.sh` checks every pair of letters in
Libertinus Serif and Sans against the font's GPOS.

## Fonts in the PDF

`tr2pdf` embeds each OpenType (CFF) font subset to the glyphs the book
uses: the glyphs it does not use, and the subroutines only they call,
are emptied (the glyphs keep their numbers, so the text is unchanged),
and the tables only typesetting needs (GSUB, GPOS, GDEF, MATH) are left
out; a TrueType font (the fallback) likewise, by its glyf and loca, a
composite glyph keeping its components; the font is named as a subset (`ABCDEF+LibertinusSerif-Regular`).
A book's PDF is a fifth of what it was, or less; every page is drawn as
with the fonts whole (`tr2pdf -W`), pixel for pixel. A font it cannot
read so (CID-keyed, Type 1 charstrings) is embedded whole.

## Speed

Complete builds against XeLaTeX and LuaLaTeX are in the README's
Benchmarks, all measured on one machine (a 4-core 2.1 GHz Xeon, emu
`-c1`). On it the dissertation's 235 pages take `book -f` 12.4
seconds for the whole build (refer, troff until its references settle,
tr2pdf), about 50 milliseconds a page; XeLaTeX takes 42.6 and LuaLaTeX
62.8. A page is painted on screen in about 20 milliseconds.

The time went where a translation from C puts it: a string made for
every character, an array allocated and zeroed for every word, a
function called to read a field. What was done about it, the output
the same byte for byte:
- A font's glyphs by name kept by character (names of one character,
  or two ASCII ones), and a word's layout (GSUB, GPOS) kept by its
  glyphs and the font's state, so neither dictionaries nor the rules
  are searched again for a word set before.
- Buffers kept between words, or made the size they need; escape
  sequences' names and arguments sliced from their strings.
- Strings for the output's commonest pieces (`hN`, `cX`, `\h'Nu'`, a
  word's font, size and colour) kept, not formatted each time.
- Paragraph filling's cost figured in `int` where it cannot overflow.

The profile is flat now: no function takes more than 4 per cent. What
remains is Dis's: reference counting on every pointer copied, frames
made and returned from (together a fifth of the time), allocation and
freeing (an eighth), and calls.

Mathematics at length is where LaTeX is still faster. A generated
(`tools/mathbook.py`)
245-page book, 30 chapters of text with 1,440 inline equations and the
23 hard displays set 360 times (numbered), takes `book` 13.0 seconds
from nothing (two passes of eqn and troff, then tr2pdf; `book -f`
13.9); its LaTeX from `book2tex` takes XeLaTeX 4.6 seconds and
LuaLaTeX 11.0, two passes each, their font caches warm (LuaLaTeX's
first run, building its cache, 30 more). The README's Benchmarks has
these beside the other documents, all on one machine. A pass of ours: eqn 1.0 seconds, troff 5.6 (the same text
without its mathematics 1.9 for its 186 pages), tr2pdf 1.8. Where it
goes:
- eqn's output is 7.4 MB of requests for 447 KB of source (125 lines
  and 25 `\w` an equation): troff measures a box by setting it (`\w`),
  so each level of an equation sets again what is in it, where TeX adds
  up dimensions it has. Measuring boxes is 1.6 seconds of troff's 5.6.
- tr2pdf's deflate, in Limbo, is two thirds of its time; level 1 for
  6 saves a fifth of it for a file a sixth larger.
- book runs the preprocessors (refer, pic, chess, tbl, eqn) once, not
  for every pass of troff.

The 23 displays alone (`tests/eqn/hard.ms`) take 0.6 seconds, emu's
start included, where XeLaTeX's start is most of its 0.8: the
difference is the start, not the setting.

Profiling compiled code: `prof` counts the interpreter's instructions,
and is no guide to where compiled code spends its time. Sample the
emulator's program counter (ptrace) instead, run with `-c5` so that the
compiler prints where each Dis instruction's code begins, and map the
samples through the module's `.sbl` to source lines. Compile troff with
its included files put into one (`include "x.b"` replaced by the file),
so that every line has one file to be in.

## LaTeX for a publisher: `book2tex`

    book2tex -p works.bib -o book.tex book.ms

writes the book as LaTeX, each of `-mbook`'s macros as the LaTeX the
table above gives it. The LaTeX is for LuaLaTeX, set as `book` sets
it:
- Libertinus, through `fontspec` and `unicode-math`.
- The page and margins, from `.papersize` and `.margins`.
- `microtype`.
- Citations by `biblatex-chicago` (its notes, the *Chicago Manual*'s
  as refer's `-S chicago`), from the BibTeX database `-p` names.
- Endnotes by `endnotes`, under each chapter's heading.
- The index by `imakeidx`, its entries makeindex's as `.index` has
  them.

Set it with:

    lualatex book; biber book; makeindex book; lualatex book; lualatex book

Troff's escapes become LaTeX's: `\fI` and `\fB` become `\emph` and
`\textbf`, a character named becomes the character, `\*` strings are
expanded. LaTeX's special characters are escaped, and troff's two
hyphens stay two.

eqn's equations become LaTeX's mathematics:
- `sub`, `sup`, `over`, `sqrt`, `from` and `to` (an operator's
  limits), `left` and `right`, `pile`, `matrix`, accents, fonts and
  defines.
- `.EQ (1.1)` is numbered with `\tag`.
- A display with `mark` and those right after it with `lineup` are one
  `align`, `&` where eqn marks and lines up, each line its `\tag` (or
  `\notag`); a two-column `matrix` with its columns pulled together
  (`matrix -100 { rcol ... lcol ... }`) is `aligned`.
- `choose` is `\binom`, `strut` `\strut`; eqnrc's names (`nabla`,
  `hbar`, `cdots`, `oint`, `oiint`, `bigoplus` and the rest) LaTeX's.
- An equation between `delim`'s characters is inline.

tbl's tables become `tabular`s, with their spans and text blocks; their
horizontal rules are booktabs' (`\toprule`, `\midrule`, `\bottomrule`),
and they have vertical rules only if the table asks for them (`vrules`),
as tbl draws them. A picture is drawn by `pic` (its labels' equations by
`eqn`, with the document's `delim` and `define`s), `troff` and `tr2pdf`
as a PDF the size of its ink (`book-pic1.pdf`, beside `-o`'s file) and
included, never wider than the column; a chess board (`.CB`) likewise,
by `chess`.

Anything with no LaTeX of its own (a macro of the book's own, say) is
kept as a comment and named on standard error.

### Articles, memoranda and journals

The class written is the source's: `-mbook`'s is LaTeX's `book`,
`-marticle`'s its `article` (two columns, or one with `.columns 1`) and
`-mmemo`'s its `article` with the memorandum's head as troff sets it.
`-m` names the macros, or the line near the top that says how the file
is set (`.\" book -m article -S numeric -p works.bib`) does. Citations
are biblatex's, in the style `-S` names as refer's: `chicago` (the
Chicago Manual's notes, biblatex-chicago's), `numeric` (numbered in the
order cited, the number before the sentence's stop as refer sets it) or
`authordate`. Each is for LuaLaTeX, in Libertinus as troff sets it; a
character the font lacks (the chess figures) comes from Noto Sans
Symbols 2 or DejaVu Sans, as troff's fallback does.

`-c` names a journal's class instead, for pdfLaTeX, as the IEEE's and
the ACM's submission systems set a paper:

    book2tex -c ieee -p works.bib -o paper.tex paper.ms          # IEEEtran, journal
    book2tex -c ieee,conference -p works.bib -o paper.tex paper.ms
    book2tex -c acm -p works.bib -o paper.tex paper.ms           # acmart, acmsmall
    book2tex -c acm,sigconf -p works.bib -o paper.tex paper.ms
    pdflatex paper; bibtex paper; pdflatex paper; pdflatex paper

| | IEEEtran | acmart |
|---|---|---|
| Authors | journal: names in a line, each's affiliation and address a `\thanks`; conference: an `\IEEEauthorblockN` and `\IEEEauthorblockA` each | `\author`, `\affiliation` (`\institution`, `\city`, `\country` from `.affil`'s parts after commas), `\email` |
| Title | `.subtitle` after a colon | `\subtitle` |
| Abstract, keywords | after `\maketitle`; `IEEEkeywords` | before `\maketitle`; `\keywords` |
| Tables | the caption above | the caption above |
| Figures | | `.alt` as `\Description` |
| Citations | BibTeX, `IEEEtran.bst`: `\cite{a,b}`, `\cite[p.~5]{a}` | BibTeX, `ACM-Reference-Format.bst` |

acmart wants every affiliation's country: it is `.affil`'s last part
after a comma (`.affil "Bell Laboratories, Murray Hill, USA"`), and
without one book2tex writes `[country]` and says so. The rights, the
venue and the CCS concepts are the ACM's to give.

For pdfLaTeX, the characters inputenc knows (with T1 and TS1: accented
Latin letters, quotation marks, dashes) are kept as written; a
mathematical one (Greek, arrows, relations, logical and set-theoretic
symbols, ℝ) is LaTeX's command, in text or an equation alike
(`\ensuremath{\rightarrow}`, or `\TextOrMath` where the text has its
own, as `…` and `×`); any other is said, and written `[U+XXXX]`. Which
characters inputenc knows was found by asking pdfLaTeX of each one.

### Acceptance

`tests/host/latex_test.sh` takes a technical paper and an essay in the
humanities (`tests/latex/`) and the examples, sets each with `book`,
writes its LaTeX for each class, and checks it as a journal would:

- book2tex says nothing; every section, float, numbered equation,
  note, label and citation of the source is in the LaTeX once; every
  environment and brace is closed; tables have no vertical rules
  unasked.
- For pdfLaTeX, every character is one inputenc knows, or a command.
- The classes' conventions (IEEEtran's keywords and table captions,
  acmart's affiliations and abstract, figures described).
- Where TeX Live is installed: each is set with no error, nothing
  undefined, no character missing from a font, every work cited in the
  bibliography.
- Every word and decimal number troff set (before the references) is
  in LaTeX's PDF: each must be in a run of three words LaTeX set at
  least as often, wherever floats went, or, read in another order (a
  table's cells), set as often. Names with accents and LaTeX's special
  characters must be there as written.

The checks were tried against fifteen wrong conversions (a phrase,
a note's sentence, a table's row, a cell's number, a citation, a note,
a figure, a heading, a label, an equation's number, a word in a
caption, a Greek word lost; a character pdfLaTeX lacks; an environment
left open): each is caught. Words reordered or repeated are not: the
test is that nothing troff set is lost.

## Manual pages: `-man` and `man -t`

`troff -man` sets a manual page as Plan 9's printed manual is set: 9
on 11 points, 6.5 inches wide, its head the page's name and section,
its foot the folio. Headings are bold at the margin and the text 3.6
ems in; commands and literals (`.B`, `.L`) are in constant width.
Libertinus Sans stands for Plan 9's Lucida Sans, Libertinus Mono for
its constant width. `man -t ls` writes troff's output for `ls(1)`;
`man -t ls | tr2pdf >ls.pdf` makes a PDF of it.

`lib/tmac/tmac.an` is written for this troff. Plan 9's macros keep a
paragraph's tag in a string made from a diversion, which Neatroff's
diversions cannot be (they hold requests); with Plan 9's file, C
Neatroff and troff alike set every page with its macros' bodies
printed as text. The macros are those InferNode's pages use:
`.TH .SH .SS .PP .LP .P .IP .TP .HP .RS .RE .PD .TF .EX .EE .SM`, and
the fonts' `.B .I .L .R` and their alternations (`.BR .IR` ...). A
tag is set as a line of its own, and its paragraph goes back up
beside it if the tag fits the indent. An alternation takes as many
words as it is given (Plan 9's take six). Arguments are compared
between BELs, as Plan 9's are, so an argument may hold a quote.
`tests/host/man_test.sh` sets every page of the manual, and checks
each macro by where it puts its words.

The toolchain's own pages are `troff(1)`, `eqn(1)`, `tbl(1)`, `pic(1)`,
`refer(1)`, `tr2pdf(1)`, `mkfn(1)`, `book(1)` (with `book2tex` and
`mkindex`) and `troff(6)`, the macro packages.

## Checking against Plan 9's troff

`tools/p9compare` sets the same input with Plan 9's troff (from
plan9port) and with this one, then shows the two side by side.
`build.sh [dir]` fetches plan9port's troff and builds it. `compare.sh
[-q] [file.tr ...]`, with `ROOT` naming the tree troff runs in, sets
each file both ways. By default it sets the probes in `tests/p9/`:
registers, conditions, diversions, traps, environments, escapes, tabs,
widths and the rest. Each page is reduced to text: every line's place
in points, its words, and its size and font where they change. The two
pages are then diffed, along with what each troff wrote on its standard
error. The two use different devices and fonts, so a difference is a
thing to read, not a failure; that is why this is a tool, not a test.

CI (`.github/workflows/ci.yml`) builds InferNode and this package over
it, installs TeX Live with the journals' classes, and runs every
`tests/host/*_test.sh`.

## Speed: what was done, and what was left

troff's pass over `tools/mathbook.py`'s 245 pages takes 6.0 seconds
of CPU (one CPU), its output byte for byte what it was before this
work: eqn
chooses a delimiter's size by the heights mkfn -M writes
(`bracketheights`), not by having troff set every size, so its output
is 6.2 MB; troff reads a file whole, uses again the buffers
pushed for strings, makes a word's buffer small and grows it, copies a
string's plain runs at once in `.ds` and `.as`, and finds two-character
names in a table. A rebuild after an edit is one pass (book stops when
the aux file does not change).

Measured and left, as worth less than they would cost:
- eqn keeping each box's width, height and depth, as TeX does, not
  having troff set a box to measure it (`\w`): at most 0.9 seconds a
  pass, a large rewrite, and placement would move (troff could no
  longer kern across boxes).
- Deflate in C: 0.77 seconds of tr2pdf's 1.97, about 5% of a book; a
  change to emu on every platform.
- What remains of troff's time is Dis's: reference counting, frames and
  returns (18%, the JIT's macros) and allocation (a quarter, emu's pools
  and libc). Sampling compiled code: run emu with `-c5`, which prints
  each module's code base, each Dis instruction's end offset and the
  macros', sample the busy thread's program counter (ptrace), and map
  the samples through the module's `.sbl`.

A test book like the one this was made for (its notes, index, tables,
equations and Greek) is the next measure.
