# troff for InferNode

A typesetting system for books, for [InferNode](https://github.com/infernode-os/infernode):
troff and its preprocessors (eqn, tbl, pic, refer, chess), PDF output (tr2pdf),
macro packages for books (`-mbook`), journal articles (`-marticle`),
memoranda and reports (`-mmemo`), a talk's slides (`-mslides`), papers
(`-ms`) and manual pages
(`-man`), an index maker, a LaTeX converter, and the Libertinus fonts.

![Two pages of a chapter set by book(1): a chapter opening with an epigraph, footnotes, displayed and inline equations, a section heading, a table and its caption](docs/images/chapter.png)

*Two pages of [`examples/chapter.ms`](examples/chapter.ms), set by
`book -p works.bib chapter.ms` ([the PDF](examples/chapter.pdf)).*

This is an add-on, not a copy of InferNode. It changes nothing in
InferNode: it is built into its own `dis/`, and put into a name space
by binding its directories after InferNode's own.

Tested in Xenith.app 0.8.0. It needs InferNode from 14 October 2026 or later
(`af0acc617`): Xenith's document engine interface, `docengine(2)`,
gained `pinned` and `viewing` then. Writing live in Xenith wants
InferNode from 25 October 2026 (infernode-os/infernode#971): before
it, what was typed beside a live document went into the text twice.

## What it sets

- **Text.** Whole paragraphs are broken at once, as TeX breaks them, not
  line by line; spaces are kept even, hyphens few and never more than
  three lines running. Widows and orphans are kept from pages' edges, and
  a page left short has its space spread so that it ends where a full
  page does. `book -f` hangs punctuation and hyphens into the margins,
  and lets a line's letters widen or narrow by up to 2% to even its
  spacing, as LaTeX's microtype does. The face is Libertinus Serif, its
  ligatures and small capitals from the font's own OpenType tables.
- **Mathematics.** eqn's language (`x sup 2`, `{a + b} over 2`,
  `sum from {i = 1} to n`), set by TeX's rules for placing each part, in
  Libertinus Math. The font's MATH table supplies the parameters, maths
  italic letters and their corrections, accents, and the sizes and
  pieces of brackets, braces and radicals. Displays are numbered, lined
  up on a sign, or set as cases and matrices.
- **A book's apparatus.** Chapters, sections, contents, footnotes and
  endnotes, cross-references by label, figures and tables that float,
  lists, quotations and epigraphs, a bibliography from a BibTeX file in
  Chicago's style (or others), and an index.
- **Articles and memoranda.** A journal's article in two columns: the
  title, authors and abstract across the page, figures and tables in a
  column or across both, notes at the foot of their column, the columns
  flush at their foot and the last page's balanced, citations numbered
  ([1]). A technical memorandum headed as Bell Laboratories' were, or a
  report.
- **Slides.** A talk's slides, with what a book has in a page: lists,
  equations, tables, pictures, programs' text, columns side by side,
  numbered citations. A slide is shown a step at a time (`.pause`),
  what is shown already never moving, and one too tall for its page is
  said, with by how much.
- **Tables, pictures and images.** tbl's tables, pic's drawings, PNG and
  JPEG images, and the first page of a PDF as a figure in vectors.
- **An accessible PDF.** The PDF is tagged and claims PDF/UA-1, and
  veraPDF agrees: headings, paragraphs, notes, lists, tables, figures
  with their descriptions, links, the bibliography and the index are its
  structure, read in order. Each equation is described in words, as a
  screen reader would speak it ("x equals the fraction with numerator
  minus b plus or minus the square root of b squared minus 4 a c, end
  root, and denominator 2 a").
- **Logic.** Formulas with the logical and modal symbols, truth
  tables, and proofs by tableau with their countermodels, as a logic
  text sets them.
- **Chess.** Diagrams from a position in Forsyth–Edwards notation, and
  moves in figurine notation (♘f3) in the text, by `chess`.
- **LaTeX for a publisher or a journal.** `book2tex` writes the same
  book, article or memorandum as LaTeX: LaTeX's own classes for
  LuaLaTeX, or IEEEtran or acmart for pdfLaTeX, as the IEEE's and the
  ACM's submission systems set a paper (`book2tex -c ieee`,
  `-c acm,sigconf`). `tests/host/latex_test.sh` checks that every word
  troff set arrives.

![Displays set by eqn: the quadratic formula, the Rogers–Ramanujan continued fraction, Ramanujan's series for 1/π, Cardano's formula, Cauchy's integral formula, the Vandermonde determinant, a function defined by cases, and the binomial theorem](docs/images/maths.png)

*Displays known to be hard to set, from
[`examples/maths.ms`](examples/maths.ms) (`book maths.ms`;
[the PDF](examples/maths.pdf)).*

## Writing a book

A book is a text file of troff with `-mbook`'s macros. This is the
start of [`examples/chapter.ms`](examples/chapter.ms):

```troff
.EQ
delim $$
.EN
.chapter "The Normal Law of Error" normal
.epigraph
The theory of probabilities is at bottom nothing but common sense
reduced to calculus.
.attrib "Laplace, \fIEssai philosophique\fP"
.endepigraph

When an astronomer measures the same angle a hundred times, the
readings scatter about a centre, the small errors many and the large
ones few. Gauss asked which law of error makes the arithmetic mean the
most probable value of the quantity measured, and found it.
.cite gauss1809 §177
If the readings are $x sub 1 , ... , x sub n$ and their errors are
independent, the law must be
.EQ (1.1)
phi ( x ) = 1 over {sigma sqrt {2 pi}} ^ e sup {- {( x - mu ) sup 2} over {2 sigma sup 2}}
.EN
where $mu$ is the true value and $sigma$ measures the spread of the
readings.\c
.fn
Gauss's own measure was the precision $h = 1 / ( sigma sqrt 2 )$; the
standard deviation $sigma$ is Pearson's, of 1894.
.fe
```

Mathematics goes between `.EQ` and `.EN`, or within a line between the
delimiters `delim` names; `.EQ (1.1)` numbers a display. `.cite` takes
a key from the bibliography (`works.bib`) and a place in the work, and
makes a note in Chicago's style. A table is tbl's, inside a floating
`.table`:

```troff
.table moments
.TS
center;
l c c c.
moment	$k = 1$	$k = 2$	$k = 3$
_
$E [ ( X - mu ) sup {2 k} ]$	$sigma sup 2$	$3 sigma sup 4$	$15 sigma sup 6$
fraction within $k sigma$	0.6827	0.9545	0.9973
.TE
.caption "The even moments of the normal law, and how much of it lies within $k$ standard deviations of the mean."
.endtable
```

and a picture is pic's, or an image or a PDF, inside a `.figure`:

```troff
.figure curve
.alt "The bell curve of the normal law, its mean marked and one standard deviation either side."
.PS
spline from (-2.5, 0.07) to (-1, 0.97) to (0, 1.6) to (1, 0.97) to (2.5, 0.07)
.PE
.caption "The normal law: two thirds of it within one standard deviation of the mean."
.endfigure
```

`.alt` describes it for those who cannot see it. Then:

    book -p works.bib chapter.ms     # chapter.pdf, tagged (PDF/UA-1)

`book` runs refer, pic, tbl and eqn once, then troff as often as the
contents, references and index need, then tr2pdf. `-f` sets the book as
it goes to press, with the margins' hanging punctuation. The pieces run
on their own as well:

    tbl paper.ms | eqn /lib/troff/eqnrc - | troff -ms | tr2pdf >paper.pdf
    troff -man /man/1/troff | tr2pdf >troff.pdf
    book2tex -p works.bib -o book.tex book.ms    # the same book as LaTeX
    book2tex -c ieee -p works.bib -o paper.tex paper.ms    # a paper for the IEEE

`man book`, `man 6 troff`, `man troff` and `man eqn` describe it all;
[`docs/TROFF.md`](docs/TROFF.md) is the design, and records what each
choice was measured against.

## In Xenith

Xenith shows troff's output as a typeset document beside its source:
the same pages as the PDF, painted from troff's output by the package's
document engine. Here the chapter's source is on the left; on the right,
its second page.

![Xenith with the chapter's troff source in one column and its second page, typeset, in the other](docs/images/xenith.png)

Put the build in the source window's tag (`book -p works.bib
chapter.ms`) and open the output (`chapter.out`) in another window.
After each Put, middle-click the build, then Get in the output's window.
Zoom+, Zoom−, Fit, PrevPage and NextPage move about the document, and
its text can be searched. The screenshot is in Xenith's Glenda theme
(`xenith -t glenda`). Setting Xenith up for it is under
[Xenith](#xenith) below.

## Articles and memoranda

`book -m article` sets a journal's article with `-marticle`: `-mbook`'s
macros with no chapters, the text in two columns. Its title, authors
(side by side) and abstract go across the page; `.figure*` and
`.table*` go across both columns at the top of the next page; notes are
set at the foot of the column their marks are in; each column ends
flush at its foot, and the last page's columns are balanced. `refer -S
numeric` cites as journals do, `[1]` in the line, the references
numbered in the order they are first cited.

    .title "Setting a Paragraph Whole"
    .author "A. Typesetter"
    .affil "InferNode Project"
    .abstract
    A paragraph broken one line at a time is broken greedily ...
    .endabstract
    .section "Introduction" intro
    Troff fills a line until the next word will not fit ...
    .cite ossanna1976

    book -m article -S numeric -p works.bib article.ms

![Two pages of a journal article set in two columns: the title, authors and abstract across the top of the first, a footnote at the foot of its column, a figure in a column, a figure across both columns at the top of the second page, the last page's columns balanced and numbered references](docs/images/article.png)

*[`examples/article.ms`](examples/article.ms) (`book -m article -S
numeric -p works.bib article.ms`; [the PDF](examples/article.pdf)).*

`book -m memo` sets a technical memorandum with `-mmemo`, headed as
Bell Laboratories' were: the subject and its file at the left; the
date, the authors and the memorandum's number at the right; `MEMORANDUM
FOR FILE` across the page below ([`examples/memo.ms`](examples/memo.ms),
[the PDF](examples/memo.pdf)). `.kind report` heads it as a report.

## Slides

`book -m slides` sets a talk with `-mslides`: `-mbook`'s macros, a
page a slide, 16:9, the type large and sans serif, the text ragged and
not hyphenated. A slide is `.slide` and its title; what follows, to
the next, is on it. `.item` begins a list of bullets if none is open.

    .title "Setting Type Whole"
    .author "A. Typesetter"
    .section "Lines"
    .slide "A line at a time"
    Troff fills a line until the next word will not fit
    .cite ossanna1976
    .pause
    .item
    A loose line is found only when it is set
    .pause
    .item
    Knuth and Plass choose every break of a paragraph at once

    book -m slides -p works.bib slides.ms

![Six slides set by -mslides: a title slide; a slide of a sentence and three bullets; bullets beside an equation; eqn's source on a tint beside the formula it sets; a table of timings; a pipeline drawn by pic](docs/images/slides.png)

*Six of the fifteen pages of [`examples/slides.ms`](examples/slides.ms)
([the PDF](examples/slides.pdf)).*

Each `.pause` ends a step: the slide is set once for each, the first
step on its first page, the first two on its next, and so on, as
beamer's `\pause` does, and what was shown already does not move. Its
pages share its number. In the tagged PDF the pages before a slide's
last are artifacts, so that the slide is read once: its structure, a
section of its own under its heading, and its links are on its last
page. `.columns`, `.column` and `.endcolumns` set text, lists,
pictures or equations side by side; `.code` sets a program's text on a
tint. `.section` is a slide of its own, beginning a part of the talk,
its slides below it among the PDF's bookmarks. Citations are numbered
(`[1]`), and `.bibliography` is a slide. A slide is set whole, once it
is known, so one too tall for its page is said, with by how much, and
runs off its page rather than onto the next. `.aspect 4:3`, `.typeface
serif` and `.accent` change the page, the face and the titles' colour.

In Xenith a file with a `.slide` is set as slides, and shown beside
its text as it is written (`Live`).

## Logic

Logic is set with the same tools: formulas by eqn, with the logical
and modal symbols from Libertinus Math (`$□ ( p → q ) , ~ □ p ~ ⊢ ~ □ q$`),
truth tables and countermodels by tbl, and proof trees by pic. The
trees here are written by `tableau` in
[infernode-wwb](https://github.com/pdfinn/infernode-wwb), from the
proofs its `prove -P` finds: each line numbered, with the line it came
from beside it, a closed branch marked ×, an open one ↑, and the
countermodel an open branch describes. Each tree is a figure,
described in words in the tagged PDF.

![Two pages of a chapter on proof by tableau: the tableau for axiom K in modal logic, an open tableau with its countermodel beside it, and a closed tableau in deontic logic](docs/images/logic.png)

*Pages 3 and 4 of [`examples/logic.ms`](examples/logic.ms) (`book
logic.ms`; [the PDF](examples/logic.pdf)): axiom K, why □p does not
give ◇p in K, and why O p gives P p in KD. The chapter also has a truth
table, modus ponens, Ross's paradox, and an argument in English that
`prove` finds does not follow.*

## Chess

`chess` sets a board between `.CB` and `.CE` from its position in
Forsyth–Edwards notation, the notation databases and engines write:

    .CB
    fen rn2kb1r/ppp1qppp/5n2/4p3/2B1P3/1Q6/PPP2PPP/RNB1K2R w
    .CE

The board is a picture, so `-mbook` centres it, keeps it on one page and
tags it as a Figure in the PDF. Its description is the position read
out ("Chess diagram. White: King e1, Queen b3, Rooks a1 and h1, …
White to move."), unless `.alt` gives another. `size`, `flip` and
`nocoords` change a board's size, turn it for Black, and leave its
squares unnamed. The pieces are the Unicode chess figures, from a subset
of Noto Sans Symbols 2 (`fonts/chess`, under the OFL). The same figures
set moves in the text: `\fB7.♕b3 ♕e7\fP`. `book` runs `chess` when a
book has a board.

![Two pages of a chapter on chess at Bell Labs: a queen-against-rook endgame, then Morphy's Opera Game with its moves in figurine notation and three diagrams](docs/images/chess.png)

*Pages 2 and 3 of [`examples/chess.ms`](examples/chess.ms) (`book
chess.ms`; [the PDF](examples/chess.pdf)): Belle and Thompson's
endgame databases, then Morphy's Opera Game of 1858.*

[`examples/linotron202/`](examples/linotron202/) sets the figures of
Condon, Kernighan and Thompson's 1980 memorandum on the Linotron 202
again ([the PDF](examples/linotron202/linotron202.pdf)): the typesetter's
block diagram, a letter e as the 202's vectors, a chess position and the
interface's schematics and timing, in pic and chess, measured from the
scan of the original. `make.sh` writes `linotron202.ms` from the sources
beside it.

## Benchmarks

Each is a complete build, from a clean directory to the finished PDF,
timed by the clock on one machine: a 4-core 2.1 GHz Xeon, Linux amd64,
TeX Live 2023. troff for InferNode runs under InferNode's JIT
(`emu -c1`), its start included, as `book -f` (microtypography on, as
`microtype` is in the LaTeX). LaTeX runs as latexmk would run it: a
pass, biber where there are citations, then passes until LaTeX stops
asking for another; font caches warm. The LaTeX for the examples and
the book of mathematics is `book2tex`'s, from the same source. Each
time is the better of two runs.

| | troff for InferNode | XeLaTeX | LuaLaTeX |
|---|---|---|---|
| [`chapter.ms`](examples/chapter.ms): 3 pages, notes, citations, equations, a table, a picture | **0.7 s** | 5.9 s (3 passes, biber) | 9.5 s (3 passes, biber) |
| [`maths.ms`](examples/maths.ms): a page of hard displays | **0.5 s** | 1.9 s (2 passes) | 3.8 s (2 passes) |
| A doctoral dissertation: 235 pages, Chicago-style notes on most of them (297 works cited), figures | **12.4 s** | 42.6 s (3 passes, biber) | 62.8 s (3 passes, biber) |
| A book of mathematics (`tools/mathbook.py`): 245 pages, 1,440 inline equations, 360 displays | 13.9 s | **4.6 s** (2 passes) | 11.0 s (2 passes) |
| Tagged PDF, conforming to PDF/UA-1 (veraPDF) | yes | no (untagged by default) | no (untagged by default) |

On the dissertation troff for InferNode is 3½ times as fast as
XeLaTeX and 5 times as fast as LuaLaTeX; on the short documents, 4 to
14 times. Where mathematics fills every page, XeLaTeX is 3 times as
fast, and LuaLaTeX a little faster. troff runs as Dis bytecode
here, and measures each part of an equation by setting it again, where
TeX keeps the sizes it has (`docs/TROFF.md`, Speed). The dissertation
was written for XeLaTeX in Minion Pro, which is not on this machine: in
both LaTeX runs Libertinus Serif replaces it, as troff sets it, and its
few Greek words go without babel's Greek, which is not installed either.

The quality of the text, on 180 pages of this tree's prose, against
LuaLaTeX with microtype on the same pages:

| | mean space | 95th percentile | lines looser than 0.5 em | lines hyphenated | two hyphens running |
|---|---|---|---|---|---|
| troff for InferNode (`book -f`) | 0.27 em | 0.38 em | 21 | 10% | 32 |
| LuaLaTeX, microtype | 0.28 em | 0.35 em | 25 | 8% | 28 |

And the mathematics: on the 23 hard displays, every part is placed
where XeLaTeX with `unicode-math` and Libertinus Math places it, to a
fraction of a point (`tests/host/maths_test.sh` checks each).

## Installing

You need a built InferNode, since the package is built with its `mk`
and `limbo`. On the host:

```sh
git clone https://github.com/pdfinn/infernode-troff troffpkg
cd troffpkg
export ROOT=/path/to/infernode
export PATH=$ROOT/MacOSX/arm64/bin:$PATH   # or Linux/amd64, and so on
mk install
```

This builds into `dis/` inside this tree. Nothing is copied into
InferNode: `ROOT` gives the build InferNode's `mkconfig` and modules
(`$ROOT/module`), and nothing is written there. On a Mac with
plan9port, InferNode's `mk` must come before plan9port's on the path.

`ROOT` is the InferNode the package is to run in. For an installed
Xenith.app, that is its runtime tree, with `mk` and `limbo` from a built
InferNode source tree:

```sh
export ROOT=/Applications/Xenith.app/Contents/Resources
export PATH=/path/to/infernode/MacOSX/arm64/bin:$PATH
mk install
```

After InferNode changes a module the package uses, build again from
clean: `mk nuke` and `mk install`.

Inside InferNode, bind it in:

```
run /n/local/path/to/troffpkg/troffns
```

`troffns` binds each of the package's directories after InferNode's
own (`bind -a`): the commands to `/dis`, the macros and device
descriptions to `/lib/tmac` and `/lib/troff`, the fonts to
`/fonts/libertinus`, the manual to `/man`. Nothing of InferNode's is
hidden. It also adds troff's two kinds of document to Xenith's
`/lib/xenith/doctypes` (below), in a copy bound over InferNode's,
unless they are there already. Run it with `run`, so that the binds are
made in the calling shell's name space. Put that line in your profile
to have troff in every session; delete it to remove it.

## Xenith

Xenith shows troff's output (`x T` in its first bytes) as a typeset
document, through the engine `dis/xenith/doc/trodoc.dis`, and a `.ms`,
`.mm`, `.me` or `.man` file as one beside its text. It finds engines
through `/lib/xenith/doctypes`, which it reads once, as it starts; the
package's kinds of document are these two lines
(`lib/troff/xenith.doctypes`):

    troff	binary	/dis/xenith/doc/trodoc.dis	magic=x\x20T\x20
    roff	source	/dis/xenith/doc/trodoc.dis	.ms .mm .me .man .roff .tr .t

So `troffns` must run before Xenith starts, in the name space Xenith
starts in. With the standalone Xenith (`Xenith.app`, `xenith`,
`tools/xen`), put it in Xenith's start-up file, which it runs before
starting Xenith (`lib/xen/boot.sh`, from infernode-os/infernode#977):
on a Mac, `~/.infernode/usr/inferno/lib/xen/profile`, one line:

    run /n/local/Users/you/src/troffpkg/troffns

with the path to where the package is built. Every Xenith started
after shows troff's documents, with nothing to edit in the app and
nothing to type in Xenith. (On the desktop, Lucifer, run it in your
profile.) Rebuild the package (`mk nuke`, `mk install`) when the app
is updated: a package built against an older InferNode's interfaces
fails to load in a newer one (`link typecheck`).

An older Xenith runs no start-up file. There, add the two lines to
InferNode's own `/lib/xenith/doctypes` (in the app,
`Xenith.app/Contents/Resources/lib/xenith/doctypes`) before starting
Xenith, and in each Xenith, `Local run
/n/local/path/to/troffpkg/troffns` (`Local`, so that its binds are made
in Xenith's own name space, not only in a command's).

A document is built, then viewed: its pipeline (refer, pic, tbl, eqn,
then troff, as often as its contents and index need) makes troff's
output, and Xenith shows that. Put the build in the source window's
tag, `book book.ms`, or a pipeline, `tbl paper.ms | troff -ms
>paper.out`, and open the output, `book.out` or `paper.out`, in another
window. After each Put, middle-click the build, then Get in the
output's window.

Or write it live, as in Typst: execute `Live` in the tag of the window
you are writing in, and a window opens below it showing the document,
set again 600 ms after you stop typing, unsaved edits and all; `Live`
again stops it. Type in the text's window, not the document's: a key
typed on a document goes back to its text, at the place last selected
there. A book, an article, a memorandum or a talk's slides are set by
`book -l`, the whole pipeline with no PDF, in a quarter to half a
second for a chapter; a line at its top says how (`.\" book -m article
-S numeric -p works.bib`). A file with a `.slide` needs no such line:
it is set as slides, each step of a slide a page. Any other `.ms`,
`.man` or `.me` file is set by `troff` with the macros its name gives. See
[docs/TROFF.md](docs/TROFF.md#writing-it-live).

## Not yet

- The tests in `tests/` were written to run inside an InferNode tree
  and have not yet been made to run against the package.
- `book2tex` writes books, articles and memoranda as LaTeX, not slides:
  `-m slides` is refused, where beamer would be wanted.

## Licence

MIT (`LICENSE`). The programs translated from Neatroff, Neateqn,
Neatrefer, Neatpost and Neatmkfn (Ali Gholami Rudi, ISC) and from Plan 9's
tbl and pic keep their notices in their sources; the macros' are in
`lib/tmac/NOTICE`, the hyphenation patterns' in `lib/troff/hyph/NOTICE`,
the fonts' in `fonts/libertinus/OFL.txt`.
