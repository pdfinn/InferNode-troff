.\" slides.ms — a talk, for -mslides: a title slide, sections, builds
.\" (.pause), columns, a program's text, equations, a table, a picture
.\" and numbered citations.
.\"
.\"	book -m slides -p works.bib slides.ms	# slides.pdf
.EQ
delim $$
.EN
.title "Setting Type Whole"
.subtitle "A troff for InferNode"
.author "A. Typesetter"
.affil "InferNode Project"
.date "November 2026"
.section "Lines" lines
.slide "A line at a time" greedy
Troff fills a line until the next word will not fit, then adjusts it
.cite ossanna1976
.pause
.item
A loose line is found only when it is set
.pause
.item
The lines before it could have helped, and are gone
.pause
.item
Knuth and Plass choose every break of a paragraph at once
.cite knuthplass1981
.slide "A paragraph broken whole" whole
.columns
.column 4.6i
.item
Each break a node; each line between two an edge
.item
The paragraph the shortest path through them
.item
A hyphen costs as a loose line does
.column 3.5i
.EQ
d = ( l + b ) sup 2 + p sup 2
.EN
.ps -4
.vs -5p
A line's demerits: \fIl\fP a constant, \fIb\fP the line's badness,
\fIp\fP the penalty of the break it ends at
.br
.ps
.vs
.endcolumns
.section "Mathematics" maths
.slide "Mathematics as it is spoken"
Kernighan and Cherry's language
.cite kernighan1975
set by TeX's rules
.cite knuth1984 ch. 17
.columns
.column 5.2i
.code
x = {- b +- sqrt {b sup 2 - 4 a c}}
    over {2 a}
.endcode
.column 2.9i
.EQ
x = {- b +- sqrt {b sup 2 - 4 a c}} over {2 a}
.EN
.endcolumns
And within a line: $e sup {i pi} + 1 = 0$.
.slide "Measured against LaTeX" timings
.TS
center;
l r r r.
	troff	XeLaTeX	LuaLaTeX
_
A chapter, 3 pages	0.7 s	5.9 s	9.5 s
A dissertation, 235 pages	12.4 s	42.6 s	62.8 s
Mathematics, 245 pages	13.9 s	4.6 s	11.0 s
.TE
.pause
.p
Where mathematics fills every page, TeX is faster: troff measures
a formula's parts by setting them again.
.section "Slides" slides
.slide "The pipeline"
.alt "Six boxes in a row, joined by arrows: refer, pic, tbl, eqn, troff and tr2pdf."
.PS
boxwid = 0.95; boxht = 0.5; linewid = 0.4
box "\s-2refer\s0"; arrow; box "\s-2pic\s0"; arrow; box "\s-2tbl\s0"; arrow
box "\s-2eqn\s0"; arrow; box "\s-2troff\s0"; arrow; box "\s-2tr2pdf\s0"
.PE
.p
\f[CR]book -m slides\fP runs those a talk needs, as for a book;
pic drew this
.cite kernighan1982
.slide "A slide, written"
.code
\&.slide "A line at a time"
Troff fills a line until \&...
\&.pause
\&.item
A loose line is found only when it is set
.endcode
.item
Each \f[CR].pause\fP shows the slide again, with more
.item
What is shown already does not move
.bibliography
