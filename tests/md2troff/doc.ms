.\" set from doc.md by md2troff
.EQ
delim $$
.EN
.ds book-lang en-GB
.columns 1
.title "The k001 \f[BI]k002\f[B] Test\f[R]\f[B]"
.subtitle "k003 of md2troff"
.author "k004 Writer"
.affil "k005 Department"
.email "k006@example.org"
.date "k007 November 2026"
.abstract
The k008 abstract, with \f[I]k009\f[R] in it.
.endabstract
.maketitle
.section "k010 Introduction" sec:intro
.p
A paragraph of k011 text with ‘k012 quoted’ words and “k013 inner”
marks, k014’s apostrophe, an en dash – and an em dash — and k015… It has
\f[I]k016\f[R], \f[B]k017\f[R], \f[BI]k018\f[R], \f[CR]k019\f[R],
\Z^k020^\v'-0.28m'\D'l \w^k020^u 0'\v'0.28m',
H\v'0.25m'\s[-2]k021\s[+2]\v'-0.25m'\f[R]O and
2\v'-0.35m'\s[-2]k022\s[+2]\v'0.35m'\f[R]. A
.link "https://example.org/k" "k023 link" ","
an address
.url "https://example.com/k024" ","
and k025.\c
.fn
The k030 note.
.p
Its k031 second paragraph.
.fe
A citation follows k026,
.cite knuth1984 17
and a reference to \*[ref sec:method] and \*[ref tbl:kinds]. Maths
$x sup 2$ and k027 costs \(Do5. A line k028
.br
broken k029.
.subsection "k032 Method" sec:method
.quote
A k033 quotation’s first paragraph, continued lazily.
.p
Its k034 second paragraph.
.quote
A k035 nested quotation.
.endquote
.endquote
.list 1
.item
k036 first item
.item
k037 second item, loose:
.p
its k038 second paragraph.
.item
k039 third item, with a list:
.list bullet
.item
k040 bullet
.item
k041 bullet
.endlist
.endlist
.list 1
.item "7)"
k042 seventh
.item "8)"
k043 eighth
.endlist
.list bullet
.item "☐"
k044 to do
.item "☒"
k045 done
.endlist
.list a
.item "a."
k046 alpha
.item "b."
k047 beta
.endlist
.code
int k048 = 1;   /* a \(Do and a \e */
\&.k049 at a line's start
.endcode
.code
k050 indented code
.endcode
.table tbl:kinds
.caption "The k058 kinds."
.TS
expand;
lB cB rB
l c r.
_
k051 Name	k052 Kind	k053 Count
_
k054	k055	1
T{
k056 with a cell long enough to be set as a block of text
T}	k057 | pipe	2
_
.TE
.endtable
.figure fig:square
.alt "A small square, grey"
.image "fig.png" 1i
.caption "The k059 figure’s caption"
.endfigure
.p
.ce
*\ \ \ *\ \ \ *
.subsubsection "k060 Unnumbered"
.p
An inline note.\c
.fn
The k061 inline note.
.fe
And k062.
.cite bringhurst2004
.subsubsection "k063 Deeper"
.EQ
y = 1 over 2
.EN
.p
k065 raw troff.
.epigraph
k067 an epigraph.
.attrib "k066 Source"
.endepigraph
.p
.link "https://example.org/r" "k068 reference link"
and
.link "https://example.org/r" "r" "."
.bibliography
