implement Book2tex;

#
# book2tex - a book, article or memorandum written with troff's macros
# (-mbook, -marticle, -mmemo), as LaTeX
#
#	book2tex [-c class[,options]] [-m macros] [-S style] [-p works.bib]
#		[-o book.tex] [book.ms]
#
# The class written is the source's (-m, or its book directive's: book,
# article or memo, as LaTeX's book and article), or a journal's that -c
# names: ieee (IEEEtran, journal or -c ieee,conference) or acm (acmart,
# acmsmall or -c acm,sigconf and the rest).  A journal's is for
# pdfLaTeX, as their submission systems set it: its citations BibTeX's,
# in the journal's style; the characters inputenc does not know written
# as LaTeX's commands (\ensuremath{\rightarrow}).
#
# Each of the macros is one of LaTeX's (docs/TROFF.md has the table),
# and is written as that: the title, its authors and abstract,
# chapters, sections, quotations, epigraphs, footnotes and endnotes,
# labels and references, figures and tables with their captions, the
# contents and lists, citations, the bibliography and the index
# (makeindex's entries, as .index has them).  Troff's escapes become
# LaTeX's: fonts, characters by name, strings.  An equation (eqn's .EQ,
# or between the delimiters delim sets) is written as LaTeX's
# mathematics, a table (tbl's .TS) as a tabular, its rules booktabs'
# (its vertical ones only if it asks, as tbl draws them).  A picture
# (pic's .PS) or a chess board (chess's .CB) is drawn by pic or chess,
# troff and tr2pdf as a PDF of its own the size of its ink,
# book-pic1.pdf and so on beside the output (-o), and included; written
# to standard output, it is left as a comment.
#
# The source's classes are for LuaLaTeX: Libertinus, as troff sets them,
# by fontspec and unicode-math; microtype; biblatex with biber, in the
# style -S names as refer's (chicago, biblatex-chicago's notes, by
# default; numeric; authordate), from the BibTeX database -p names (the
# source's stem.bib by default).
#	lualatex book; biber book; makeindex book; lualatex book; lualatex book
#
# A request or macro with no LaTeX of its own is written as a comment
# (% troff: ...), and said once on standard error.
#

include "sys.m";
	sys: Sys;
include "draw.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "sh.m";
include "math.m";
	math: Math;

Book2tex: module
{
	init: fn(ctxt: ref Draw->Context, args: list of string);
};

stderr: ref Sys->FD;
ctxt: ref Draw->Context;

# fonts
R, I, B, BI, SC, TT: con iota;

# what is being written: the book, or a note's or epigraph's text
Out: adt {
	l:	list of string;	# its lines, the last first
	want:	int;	# the font the text is in
	prev:	int;	# the font before (\fP)
	open:	int;	# the font open in what is written
	cont:	int;	# the last line ended in \c: the next joins it
	intext:	int;	# text since the paragraph began
	noindent:	int;	# the next text continues a paragraph (after .sp)
	fnmarked:	int;	# \*[fnmark] placed the note's mark
	enmarked:	int;
	nf:	int;	# no filling (.nf): a line a line
	nfline:	int;	# the last line was one of .nf's text
};

cur: ref Out;
innote := 0;	# the text is a note's
closeparen := 0;	# a note's ) to be \bibcloseparen, its ( a citation's open
parendepth := 0;	# the parentheses opened since
notecited := 0;	# the note's last line ends in a citation

# the input: files, .so's on top
Inp: adt {
	f:	ref Iobuf;
	name:	string;
	line:	int;
};
inputs: list of ref Inp;
pushed: list of string;	# lines to be read again

# the book's settings, for the preamble
bib := "";
srcname := "";
outname := "";
papersize := array[2] of {"6in", "9in"};
margins := array[4] of {"0.75in", "0.875in", "0.875in", "0.75in"};
ptsize := "11pt";
title := "";
subtitle := "";
author := "";
date := "";
haveepigraph := 0;
haveendnotes := 0;
havecites := 0;
haveindex := 0;
havepics := 0;
havetables := 0;
haveurls := 0;
numbered := 1;	# chapters numbered (\mainmatter's)
chapnum := 0;
enhead := "";	# the heading of the chapter's endnotes, until its first
npics := 0;
lists: list of string;	# the lists open (enumerate, itemize), innermost first
infloat := "";	# the float open (figure, table): its pictures and tables centred by it
floatlabel := "";
floatat := 0;	# the lines written when the float began, its caption's place above
alttext := "";	# .alt's description of the next picture

# the class: the source's macros, and what is written for them
macros := "";	# book, article or memo (-m, the book directive's)
cls := "";	# book, article, memo, ieee or acm (-c)
clsopts := "";	# the class's options (-c acm,sigconf)
style := "";	# the citations': chicago (notes), authordate or numeric (-S)
styleopts := "";	# its options (chicago,nodoi)
pdftex := 0;	# for pdfLaTeX (a journal's), not LuaLaTeX
columns := 2;	# -marticle's (.columns)
Author: adt {
	name:	string;
	affil:	string;
	email:	string;
	loc:	string;	# a memorandum's: where, and the extension
	ext:	string;
};
authors: list of ref Author;	# the last first
abstract := "";
keywords := "";
titlemade := 0;
bibmade := 0;
memoorg := "";
memocase := "";
memofile := "";
memonumber := "";
memotype := "MEMORANDUM FOR FILE";
memokind := "memo";
eqprelude := "";	# eqn's settings (delim, define), for a picture's labels
trprelude := "";	# the document's characters (.char, .fp), for a picture's

# strings (.ds), and the characters troff names
strs: list of (string, string);
chars: list of (string, string);
said: list of string;	# what has been said on standard error

# eqn's inline delimiters
dl1 := 0;
dl2 := 0;

init(c: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	math = load Math Math->PATH;
	stderr = sys->fildes(2);
	ctxt = c;
	args = tl args;
	while(args != nil && len hd args > 1 && (hd args)[0] == '-'){
		o := hd args;
		args = tl args;
		if(o == "-p" && args != nil){
			bib = hd args;
			args = tl args;
		}else if(o == "-c" && args != nil){
			(cls, clsopts) = split1(hd args, ',');
			args = tl args;
		}else if(o == "-m" && args != nil){
			macros = hd args;
			args = tl args;
		}else if(o == "-S" && args != nil){
			(style, styleopts) = split1(hd args, ',');
			args = tl args;
		}else if(o == "-o" && args != nil){
			outname = hd args;
			args = tl args;
		}else
			usage();
	}
	f: ref Iobuf;
	if(args == nil){
		f = bufio->fopen(sys->fildes(0), Bufio->OREAD);
		srcname = "book.ms";
	}else{
		if(tl args != nil)
			usage();
		srcname = hd args;
		f = bufio->open(srcname, Bufio->OREAD);
		if(f == nil){
			sys->fprint(stderr, "book2tex: %s: %r\n", srcname);
			raise "fail:open";
		}
	}
	inputs = ref Inp(f, srcname, 0) :: nil;
	if(args != nil)
		bookdirective(srcname);
	if(macros == "")
		macros = "book";
	case macros {
	"book" or "article" or "memo" =>	;
	* =>
		sys->fprint(stderr, "book2tex: -m %s: not book, article or memo\n", macros);
		raise "fail:usage";
	}
	if(style == "")
		style = "chicago";
	case style {
	"chicago" or "authordate" or "numeric" =>	;
	* =>
		sys->fprint(stderr, "book2tex: -S %s: not chicago, authordate or numeric\n", style);
		raise "fail:usage";
	}
	if(cls == "")
		cls = macros;
	case cls {
	"book" or "article" or "memo" =>	;
	"ieee" or "acm" =>
		pdftex = 1;
	* =>
		sys->fprint(stderr, "book2tex: -c %s: not book, article, memo, ieee or acm\n", cls);
		raise "fail:usage";
	}
	# -marticle's page and type: letter, 10 points, margins of three
	# quarters of an inch; -mmemo's 11 points, an inch, one column
	case macros {
	"article" =>
		papersize = array[] of {"8.5in", "11in"};
		margins = array[] of {"0.75in", "0.75in", "0.75in", "0.75in"};
		ptsize = "10pt";
	"memo" =>
		papersize = array[] of {"8.5in", "11in"};
		margins = array[] of {"1in", "1in", "1in", "1in"};
		columns = 1;
	}
	loadchars();
	cur = newout();
	{
		book();
	}exception e{
	"fail:*" =>
		raise e;
	"*" =>
		sys->fprint(stderr, "book2tex: %s, %s line %d\n", e, inname(), inline());
		raise "fail:" + e;
	}
	closefont(cur);
	o: ref Iobuf;
	if(outname != nil){
		o = bufio->create(outname, Bufio->OWRITE, 8r666);
		if(o == nil){
			sys->fprint(stderr, "book2tex: %s: %r\n", outname);
			raise "fail:create";
		}
	}else
		o = bufio->fopen(sys->fildes(1), Bufio->OWRITE);
	if(macros != "book" && !titlemade && (title != "" || authors != nil))
		maketitle();
	if(havecites && !bibmade && !biblatex()){
		warn("citations, and no .bibliography: the references set at the end");
		bibliography();
	}
	o.puts(texchars(preamble()));
	for(l := rev(cur.l); l != nil; l = tl l){
		o.puts(texchars(hd l));
		o.putc('\n');
	}
	o.puts("\\end{document}\n");
	o.close();
}

# s split at its first c: what is before it, and what is after
split1(s: string, c: int): (string, string)
{
	for(i := 0; i < len s; i++)
		if(s[i] == c)
			return (s[0:i], s[i + 1:]);
	return (s, "");
}

# the options book(1) is given in the source's first lines, as the
# document views read them: .\" book -m article -S numeric -p works.bib;
# those given here first
bookdirective(name: string)
{
	f := bufio->open(name, Bufio->OREAD);
	if(f == nil)
		return;
	for(n := 0; n < 20 && (s := f.gets('\n')) != nil; n++){
		if(!prefix(".\\\"", s))
			continue;
		(nil, w) := sys->tokenize(s[3:], " \t\r\n");
		if(w == nil || hd w != "book")
			continue;
		for(w = tl w; w != nil && tl w != nil; w = tl w){
			v := hd tl w;
			case hd w {
			"-m" =>
				if(macros == "")
					macros = v;
			"-S" =>
				if(style == "")
					(style, styleopts) = split1(v, ',');
			"-p" =>
				if(bib == "")
					bib = v;
			* =>
				continue;
			}
			w = tl w;
		}
		return;
	}
}

usage()
{
	sys->fprint(stderr, "usage: book2tex [-c class[,options]] [-m macros] [-S style] [-p works.bib] [-o book.tex] [book.ms]\n");
	raise "fail:usage";
}

warn(s: string)
{
	for(l := said; l != nil; l = tl l)
		if(hd l == s)
			return;
	said = s :: said;
	sys->fprint(stderr, "book2tex: %s (%s line %d)\n", s, inname(), inline());
}

inname(): string
{
	if(inputs == nil)
		return srcname;
	return (hd inputs).name;
}

inline(): int
{
	if(inputs == nil)
		return 0;
	return (hd inputs).line;
}

newout(): ref Out
{
	return ref Out(nil, R, R, R, 0, 0, 0, 0, 0, 0, 0);
}

rev(l: list of string): list of string
{
	r: list of string;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

ch(c: int): string
{
	s := "x";
	s[0] = c;
	return s;
}

isalpha(c: int): int
{
	return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z';
}

isdigit(c: int): int
{
	return c >= '0' && c <= '9';
}

prefix(p, s: string): int
{
	return len s >= len p && s[0:len p] == p;
}

suffix(p, s: string): int
{
	return len s >= len p && s[len s - len p:] == p;
}

trim(s: string): string
{
	i := 0;
	while(i < len s && (s[i] == ' ' || s[i] == '\t'))
		i++;
	j := len s;
	while(j > i && (s[j - 1] == ' ' || s[j - 1] == '\t'))
		j--;
	return s[i:j];
}

join(l: list of string, sep: string): string
{
	s := "";
	for(; l != nil; l = tl l){
		s += hd l;
		if(tl l != nil)
			s += sep;
	}
	return s;
}

# the input, a line at a time; a line ending in \ goes on on the next;
# a blank line is " "
readline(): string
{
	if(pushed != nil){
		s := hd pushed;
		pushed = tl pushed;
		return s;
	}
	s := "";
	for(;;){
		if(inputs == nil)
			return nil;
		in := hd inputs;
		t := in.f.gets('\n');
		if(t == nil){
			inputs = tl inputs;
			if(s != "")
				return s;
			continue;
		}
		in.line++;
		if(t[len t - 1] == '\n')
			t = t[0:len t - 1];
		n := 0;
		for(i := len t - 1; i >= 0 && t[i] == '\\'; i--)
			n++;
		if(n % 2){
			s += t[0:len t - 1];
			continue;
		}
		s += t;
		if(s == "")
			return " ";	# a blank line: "" is nil, the end
		return s;
	}
}

unread(s: string)
{
	pushed = s :: pushed;
}

#
# what is written
#

# a line of its own
emit(o: ref Out, s: string)
{
	o.l = s :: o.l;
	o.cont = 0;
}

# added to the last line
joinlast(o: ref Out, s: string)
{
	if(o.l == nil)
		o.l = s :: nil;
	else
		o.l = (hd o.l + s) :: tl o.l;
}

opener(f: int): string
{
	case f {
	I =>	return "\\emph{";
	B =>	return "\\textbf{";
	BI =>	return "\\textbf{\\emph{";
	SC =>	return "\\textsc{";
	TT =>	return "\\texttt{";
	}
	return "";
}

closer(f: int): string
{
	case f {
	R =>	return "";
	BI =>	return "}}";
	}
	return "}";
}

# added to the last line, unless that ends a paragraph
attach(o: ref Out, s: string)
{
	if(o.l == nil || hd o.l == "")
		emit(o, s);
	else
		joinlast(o, s);
}

# what puts the text in its font
fontsync(o: ref Out): string
{
	if(o.want == o.open)
		return "";
	s := closer(o.open) + opener(o.want);
	o.open = o.want;
	return s;
}

closefont(o: ref Out)
{
	if(o.open != R){
		joinlast(o, closer(o.open));
		o.open = R;
	}
}

setfont(o: ref Out, f: int)
{
	if(f < 0)
		f = o.prev;
	o.prev = o.want;
	o.want = f;
}

fontnamed(s: string): int
{
	case s {
	"R" or "1" =>	return R;
	"I" or "2" =>		return I;
	"B" or "3" =>		return B;
	"BI" or "4" =>		return BI;
	"SC" =>		return SC;
	"CW" or "CR" or "C" or "TT" =>	return TT;
	"P" or "" =>	return -1;
	}
	warn("font " + s + " set as roman");
	return R;
}

# a line of text
textline(o: ref Out, s: string)
{
	j := o.cont;
	o.cont = 0;
	# (after a citation in a note, its punctuation joined to it)
	if(innote && notecited && s != "" && (s[0] == ',' || s[0] == ';' || s[0] == ':' || s[0] == ')' ||
			s[0] == ']' || s[0] == '?' || s[0] == '!' || s[0] == '.'))
		j = 1;
	notecited = 0;
	t := text(o, s);
	if(o.noindent && !j){
		t = "\\noindent " + t;
		o.noindent = 0;
	}
	if(o.nf){
		if(o.nfline && !j)
			joinlast(o, "\\newline");
		o.nfline = 1;
	}
	c := o.cont;
	if(j && o.l != nil)
		joinlast(o, t);
	else
		emit(o, t);
	o.cont = c;
	o.intext = 1;
}

# text, with what it has open closed: a heading's, an argument's
textarg(s: string): string
{
	o := newout();
	t := text(o, s);
	return t + closer(o.open);
}

# troff's text as LaTeX's
text(o: ref Out, s: string): string
{
	r := "";
	i := 0;
	col := 0;	# unfilled (.nf), the column: its spaces kept, tabs every eight
	while(i < len s){
		c := s[i];
		if(c == '\\' && i + 1 < len s){
			(t, n) := escape(o, s, i);
			if(t != "")
				r += fontsync(o) + t;
			i = n;
			continue;
		}
		if(c == '\\'){	# alone at the end
			i++;
			continue;
		}
		if(dl1 && c == dl1){
			j := i + 1;
			while(j < len s && s[j] != dl2)
				j++;
			if(j < len s){
				r += fontsync(o) + "$" + eqn(s[i + 1:j], 0) + "$";
				i = j + 1;
				continue;
			}
		}
		# (a space between words is a space; one more, or one leading
		# the line, kept)
		# (a note's ) closing the ( a citation was in: biblatex's)
		if(closeparen > 0 && innote){
			if(c == '(')
				parendepth++;
			else if(c == ')' && parendepth > 0)
				parendepth--;
			else if(c == ')'){
				r += fontsync(o) + "\\bibcloseparen{}";
				closeparen--;
				i++;
				continue;
			}
		}
		if(o.nf && (c == ' ' || c == '\t') && !(c == ' ' && i > 0 && s[i - 1] != ' ' && s[i - 1] != '\t' &&
				i + 1 < len s && s[i + 1] != ' ' && s[i + 1] != '\t')){
			n := 1;
			if(c == '\t')
				n = 8 - col % 8;
			for(; n > 0; n--){
				r += "~";
				col++;
			}
			i++;
			continue;
		}
		col++;
		t: string;
		case c {
		'#' or '$' or '%' or '&' or '_' or '{' or '}' =>
			t = "\\" + ch(c);
		'~' =>
			t = "\\textasciitilde{}";
		'^' =>
			t = "\\textasciicircum{}";
		'-' =>
			# troff's two hyphens are two, not LaTeX's dash
			if(i + 1 < len s && s[i + 1] == '-')
				t = "-{}";
			else
				t = "-";
		* =>
			t = ch(c);
		}
		# a space ends a font, but does not begin one
		if(c != ' ' && c != '\t' || o.want == R)
			r += fontsync(o);
		r += t;
		i++;
	}
	return r;
}

# an escape's argument, between the character after the escape and that
# character again (\h'1m'); its end
delimarg(s: string, i: int): (string, int)
{
	if(i >= len s)
		return ("", i);
	d := s[i];
	j := i + 1;
	while(j < len s && s[j] != d)
		j++;
	if(j >= len s)
		return (s[i + 1:], j);
	return (s[i + 1:j], j + 1);
}

# a name after an escape: x, (xx or [name]; its end
escname(s: string, i: int): (string, int)
{
	if(i >= len s)
		return ("", i);
	if(s[i] == '('){
		if(i + 3 > len s)
			return (s[i + 1:], len s);
		return (s[i + 1:i + 3], i + 3);
	}
	if(s[i] == '['){
		j := i + 1;
		while(j < len s && s[j] != ']')
			j++;
		if(j >= len s)
			return (s[i + 1:], j);
		return (s[i + 1:j], j + 1);
	}
	return (ch(s[i]), i + 1);
}

# an escape at s[i] (a backslash): its LaTeX, and the end
escape(o: ref Out, s: string, i: int): (string, int)
{
	c := s[i + 1];
	i += 2;
	case c {
	'\\' or 'e' or 'E' =>
		return ("\\textbackslash{}", i);
	'-' =>
		return ("−", i);
	'%' =>
		if(i - 3 >= 0 && i < len s && isalpha(s[i - 3]) && isalpha(s[i]))
			return ("\\-", i);
		return ("", i);
	'&' or ')' or 'z' or 'p' or 'r' or 'u' or 'd' or 'a' or '{' or '}' =>
		return ("", i);
	':' =>
		return ("\\allowbreak{}", i);
	' ' or '~' =>
		return ("~", i);
	'0' =>
		return ("\\hphantom{0}", i);
	'|' =>
		return ("\\,", i);
	'^' =>
		return ("\\hspace{0.0833em}", i);
	't' =>
		return (" ", i);
	'.' =>
		return (".", i);
	'\'' =>
		return ("´", i);
	'`' =>
		return ("`", i);
	'_' =>
		return ("\\_", i);
	'"' or '#' =>
		return ("", len s);
	'c' =>
		if(i >= len s)
			o.cont = 1;
		return ("", i);
	'f' =>
		(n, e) := escname(s, i);
		setfont(o, fontnamed(n));
		return ("", e);
	's' =>
		if(i < len s && (s[i] == '+' || s[i] == '-'))
			i++;
		if(i < len s && (s[i] == '(' || s[i] == '['))
			return ("", escname(s, i).t1);
		if(i < len s && s[i] == '\'')
			return ("", delimarg(s, i).t1);
		while(i < len s && isdigit(s[i]) && i < len s)
			i++;
		return ("", i);
	'(' or '[' =>
		(n, e) := escname(s, i - 1);
		return (tchar(n), e);
	'C' =>
		(n, e) := delimarg(s, i);
		return (tchar(n), e);
	'*' =>
		(n, e) := escname(s, i);
		return (strval(o, n), e);
	'n' =>
		if(i < len s && (s[i] == '+' || s[i] == '-'))
			i++;
		(n, e) := escname(s, i);
		if(n == "%")
			return ("\\thepage{}", e);
		return ("", e);
	'h' or 'v' or 'X' or 'w' or 'o' or 'D' or 'l' or 'L' or 'b' or 'x' or 'R' or 'Z' or 'N' or 'A' or 'B' or 'S' or 'H' =>
		(nil, e) := delimarg(s, i);
		return ("", e);
	'k' or 'g' or '$' or 'm' or 'M' or 'F' or 'Y' or 'V' =>
		(nil, e) := escname(s, i);
		return ("", e);
	}
	return (ch(c), i);
}

# a character troff names, as LaTeX writes it
tchar(n: string): string
{
	case n {
	"lq" =>	return "``";
	"rq" =>	return "''";
	"oq" =>	return "`";
	"cq" or "aq" =>	return "'";
	"em" =>	return "---";
	"en" =>	return "--";
	"hy" =>	return "-";
	"dq" =>	return "\"";
	"rs" or "\\" =>	return "\\textbackslash{}";
	"ti" =>	return "\\textasciitilde{}";
	"ha" =>	return "\\textasciicircum{}";
	"ul" or "_" =>	return "\\_";
	"sl" =>	return "/";
	"sh" =>	return "\\#";
	"Do" =>	return "\\$";
	"%" =>	return "\\%";
	"&" =>	return "\\&";
	"lC" =>	return "\\{";
	"rC" =>	return "\\}";
	"fi" or "fl" or "ff" or "Fi" or "Fl" =>	return n;
	}
	for(l := chars; l != nil; l = tl l)
		if((hd l).t0 == n)
			return (hd l).t1;
	warn("no character \\(" + n);
	return "";
}

# troff's names of characters, from the device's descriptions of its
# fonts: char name, then its width (or " for the character before) and
# its code
loadchars()
{
	for(fl := "R" :: "S" :: "DF" :: nil; fl != nil; fl = tl fl){
		f := bufio->open("/lib/troff/devutf/" + hd fl, Bufio->OREAD);
		if(f == nil)
			continue;
		last := "";
		while((s := f.gets('\n')) != nil){
			if(!prefix("char ", s))
				continue;
			(nil, fl2) := sys->tokenize(s[5:], "\t\n");
			if(fl2 == nil || tl fl2 == nil)
				continue;
			name := hd fl2;
			if(hd tl fl2 == "\""){
				if(last != "")
					chars = (name, last) :: chars;
				continue;
			}
			last = "";
			# width, type, glyph, code
			l := tl fl2;
			for(k := 0; k < 3 && l != nil; k++)
				l = tl l;
			# a character beyond ASCII is its own name, its code left out
			if(l != nil && int hd l > 32)
				last = ch(int hd l);
			else if(len name == 1 && name[0] > 16r7f)
				last = name;
			else
				continue;
			if(len name > 1)
				chars = (name, last) :: chars;
		}
	}
}

# a string's value: \*[ref name], \*[cite key loc] and the like, or the
# book's own (.ds)
strval(o: ref Out, n: string): string
{
	(nil, w) := sys->tokenize(n, " ");
	if(w == nil)
		return "";
	name := hd w;
	arg := "";
	if(len n > len name)
		arg = trim(n[len name:]);
	case name {
	"ref" =>
		return "\\ref{" + arg + "}";
	"pageref" =>
		return "\\pageref{" + arg + "}";
	"fnmark" =>
		o.fnmarked = 1;
		return "\\footnotemark{}";
	"enmark" =>
		o.enmarked = 1;
		haveendnotes = 1;
		return "\\endnotemark{}";
	"cite" =>
		havecites = 1;
		return cites("\\cite", arg);
	"TeX" or "LaTeX" =>	# (tmac.logos's: LaTeX's own)
		return "\\" + name + "{}";
	}
	for(l := strs; l != nil; l = tl l)
		if((hd l).t0 == name)
			return text(o, (hd l).t1);
	warn("no string " + name);
	return "";
}

# a citation: \autocite[loc]{key}, or \autocites[loc]{key}[loc]{key};
# BibTeX's: \cite{key,key}, or \cite[loc]{key}, \cite{key}
cites(cmd: string, s: string): string
{
	if(!biblatex())
		return bibtexcites(s);
	r := "";
	n := 0;
	(nil, l) := sys->tokenize(s, ";");
	for(; l != nil; l = tl l){
		c := trim(hd l);
		if(c == "")
			continue;
		key := c;
		loc := "";
		for(i := 0; i < len c; i++)
			if(c[i] == ' ' || c[i] == '\t'){
				key = c[0:i];
				loc = trim(c[i:]);
				break;
			}
		if(loc != "")
			r += "[" + range(textarg(loc)) + "]";
		r += "{" + key + "}";
		n++;
	}
	if(n > 1)
		return cmd + "s" + r;
	return cmd + r;
}

bibtexcites(s: string): string
{
	keys, all: list of string;
	haveloc := 0;
	(nil, l) := sys->tokenize(s, ";");
	for(; l != nil; l = tl l){
		c := trim(hd l);
		if(c == "")
			continue;
		(key, loc) := split1(c, ' ');
		loc = trim(loc);
		keys = key :: keys;
		if(loc != ""){
			haveloc = 1;
			# a number or a range a page or pages, as refer's numbered
			# style has it (p. 5, pp. 151--57); anything else as given
			pl := range(textarg(loc));
			if(isdigit(pl[0])){
				if(contains(pl, "-"))
					pl = "pp.~" + pl;
				else
					pl = "p.~" + pl;
			}
			all = "\\cite[" + pl + "]{" + key + "}" :: all;
		}else
			all = "\\cite{" + key + "}" :: all;
	}
	if(!haveloc)
		return "\\cite{" + join(rev(keys), ",") + "}";
	return join(rev(all), ", ");
}

# a citation after the text it cites: a note's mark after its
# punctuation (Chicago's notes), else the citation before it, joined to
# the word by a tie (spaces~[1]. as refer's numbered style sets it)
citeattach(o: ref Out, c: string)
{
	if(o.l == nil || hd o.l == ""){
		attach(o, c);
		return;
	}
	if(biblatex() && style == "chicago"){
		# in a note, the citation is in its text, after a space; in the
		# text, a note's mark, after the word or its punctuation
		if(innote){
			# (citations one after another apart by semicolons; in
			# parentheses, biblatex's, so that the citation's own are
			# brackets, as the Chicago Manual has them)
			l := hd o.l;
			if(notecited)
				c = "; " + c;
			else if(!suffix(" ", l) && !suffix("(", l))
				c = " " + c;
			if(openparen(o)){
				closeparen++;
				parendepth = 0;
			}
			attach(o, c);
			notecited = 1;
			return;
		}
		attach(o, c);
		return;
	}
	l := hd o.l;
	i := len l;
	while(i > 0 && (l[i - 1] == '.' || l[i - 1] == ',' || l[i - 1] == ';' || l[i - 1] == ':' ||
			l[i - 1] == '!' || l[i - 1] == '?'))
		i--;
	j := i;
	while(j > 0 && l[j - 1] == ' ')
		j--;
	o.l = (l[0:j] + "~" + c + l[i:]) :: tl o.l;
}

# the note's last ( not closed made biblatex's \bibopenparen; whether
# there was one
openparen(o: ref Out): int
{
	a := array[nlines(o)] of string;
	k := len a;
	for(l := o.l; l != nil; l = tl l)
		a[--k] = hd l;
	(ln, at) := (-1, -1);
	stk: list of (int, int);
	for(k = 0; k < len a; k++)
		for(i := 0; i < len a[k]; i++)
			case a[k][i] {
			'\\' =>
				i++;
			'(' =>
				stk = (k, i) :: stk;
			')' =>
				if(stk != nil)
					stk = tl stk;
			}
	if(stk == nil)
		return 0;
	(ln, at) = hd stk;
	a[ln] = a[ln][0:at] + "\\bibopenparen{}" + a[ln][at + 1:];
	o.l = nil;
	for(k = 0; k < len a; k++)
		o.l = a[k] :: o.l;
	return 1;
}

# a URL in \url's argument: its % and # escaped, as hyperref has them in
# another command's
urlesc(s: string): string
{
	r := "";
	for(i := 0; i < len s; i++){
		if(s[i] == '%' || s[i] == '#')
			r += "\\";
		r[len r] = s[i];
	}
	return r;
}

# 315-16 as 315--16
range(s: string): string
{
	r := "";
	for(i := 0; i < len s; i++){
		if(s[i] == '-' && i > 0 && i + 1 < len s && isdigit(s[i - 1]) && isdigit(s[i + 1]))
			r += "--";
		else
			r[len r] = s[i];
	}
	return r;
}

# a request's arguments, as troff reads them
reqargs(s: string): list of string
{
	r: list of string;
	i := 0;
	for(;;){
		while(i < len s && (s[i] == ' ' || s[i] == '\t'))
			i++;
		if(i >= len s)
			break;
		a := "";
		if(s[i] == '"'){
			i++;
			while(i < len s){
				if(s[i] == '"'){
					if(i + 1 < len s && s[i + 1] == '"'){
						a[len a] = '"';
						i += 2;
						continue;
					}
					i++;
					break;
				}
				a[len a] = s[i++];
			}
		}else{
			while(i < len s && s[i] != ' ' && s[i] != '\t')
				a[len a] = s[i++];
		}
		r = a :: r;
	}
	return rev(r);
}

arg(l: list of string, n: int): string
{
	for(; l != nil && n > 0; l = tl l)
		n--;
	if(l == nil)
		return "";
	return hd l;
}

# a length, troff's units as LaTeX's
dimen(s: string): string
{
	t := "";
	for(i := 0; i < len s; i++)
		if(s[i] != '(' && s[i] != ')')
			t[len t] = s[i];
	if(t == "")
		return "0pt";
	case t[len t - 1] {
	'i' =>	return t[0:len t - 1] + "in";
	'c' =>	return t[0:len t - 1] + "cm";
	'p' =>	return t[0:len t - 1] + "pt";
	'P' =>	return t[0:len t - 1] + "pc";
	'm' =>	return t[0:len t - 1] + "em";
	'n' =>	return t[0:len t - 1] + "en";
	'v' =>	return t[0:len t - 1] + "\\baselineskip";
	'u' =>	return t[0:len t - 1] + "sp";
	}
	return t + "\\baselineskip";
}

#
# the book
#

book()
{
	blank := 0;
	while((s := readline()) != nil){
		if(s == "" || trim(s) == ""){
			if(!blank)
				paragraph();
			blank = 1;
			continue;
		}
		blank = 0;
		if(s[0] == '.' || s[0] == '\''){
			request(s);
			continue;
		}
		textline(cur, s);
	}
}

paragraph()
{
	o := cur;
	closefont(o);
	if(o.nf){
		emit(o, "");
		o.nfline = 0;
		return;
	}
	if(o.l != nil && hd o.l != "")
		emit(o, "");
	o.intext = 0;
	o.noindent = 0;
}

# a line of LaTeX of its own, what is open closed
# a line of .code as it was typed: \e a backslash, \& nothing, \(Do a
# dollar, \(dq a double quote
verbatim(t: string): string
{
	r := "";
	for(i := 0; i < len t; i++){
		if(t[i] != '\\' || i + 1 >= len t){
			r[len r] = t[i];
			continue;
		}
		if(t[i+1] == 'e'){
			r[len r] = '\\';
			i++;
		}else if(t[i+1] == '&')
			i++;
		else if(i + 3 < len t && t[i+1:i+4] == "(Do"){
			r[len r] = '$';
			i += 3;
		}else if(i + 3 < len t && t[i+1:i+4] == "(dq"){
			r[len r] = '"';
			i += 3;
		}else
			r[len r] = t[i];
	}
	return r;
}

block(s: string)
{
	closefont(cur);
	emit(cur, s);
	cur.intext = 0;
	cur.noindent = 0;
}

request(s: string)
{
	i := 1;
	while(i < len s && (s[i] == ' ' || s[i] == '\t'))
		i++;
	if(i + 1 < len s && s[i] == '\\' && (s[i + 1] == '"' || s[i + 1] == '#')){
		closefont(cur);
		emit(cur, "%" + s[i + 2:]);
		cur.cont = 0;
		return;
	}
	j := i;
	while(j < len s && s[j] != ' ' && s[j] != '\t')
		j++;
	name := s[i:j];
	rest := s[j:];
	a := reqargs(rest);
	case name {
	"" =>
		;
	"title" =>
		title = textarg(join(a, " "));
	"subtitle" =>
		subtitle = textarg(join(a, " "));
	"author" =>
		if(macros == "book"){
			author = textarg(join(a, " "));
			authors = ref Author(author, "", "", "", "") :: nil;
		}else{
			authors = ref Author(textarg(arg(a, 0)), "", "", textarg(arg(a, 1)), textarg(arg(a, 2))) :: authors;
			if(author != "")
				author += " \\and ";
			author += (hd authors).name;
		}
	"affil" =>
		if(authors != nil)
			(hd authors).affil = textarg(join(a, " "));
	"email" =>
		if(authors != nil)
			(hd authors).email = textarg(join(a, " "));
	"keywords" =>
		keywords = textarg(join(a, " "));
	"abstract" =>
		t := captured(".endabstract");
		if(titlemade){
			block("\\begin{abstract}");
			emit(cur, t);
			emit(cur, "\\end{abstract}");
			cur.noindent = 1;
		}else
			abstract = t;
	"endabstract" =>
		;
	"columns" =>
		if(arg(a, 0) == "1" || arg(a, 0) == "2")
			columns = int arg(a, 0);
	"org" =>
		memoorg = textarg(join(a, " "));
	"case" =>
		memocase = textarg(join(a, " "));
	"file" =>
		memofile = textarg(join(a, " "));
	"number" =>
		memonumber = textarg(join(a, " "));
	"memotype" =>
		memotype = textarg(join(a, " "));
	"kind" =>
		memokind = arg(a, 0);
	"signature" =>
		blankline();
		block("\\begin{flushright}");
		names: list of string;
		for(al := authors; al != nil; al = tl al)
			names = (hd al).name :: names;
		emit(cur, join(names, "\\\\"));
		emit(cur, "\\end{flushright}");
	"date" =>
		date = textarg(join(a, " "));
	"maketitle" =>
		maketitle();
	"frontmatter" =>
		numbered = 0;
		block("\\frontmatter");
	"mainmatter" =>
		numbered = 1;
		block("\\mainmatter");
	"backmatter" =>
		numbered = 0;
		block("\\backmatter");
	"part" =>
		blankline();
		block("\\part{" + textarg(arg(a, 0)) + "}");
	"chapter" or "chapter*" =>
		blankline();
		t := textarg(arg(a, 0));
		if(name == "chapter*"){
			block("\\chapter*{" + t + "}");
			if(arg(a, 0) != "Contents")
				emit(cur, "\\addcontentsline{toc}{chapter}{" + t + "}");
			emit(cur, "\\markboth{" + t + "}{" + t + "}");
			enhead = t;
		}else{
			if(arg(a, 2) != "")	# its short title, the running head's
				block("\\chapter[" + textarg(arg(a, 2)) + "]{" + t + "}");
			else
				block("\\chapter{" + t + "}");
			if(numbered){
				chapnum++;
				enhead = "Chapter " + string chapnum + ": " + t;
			}else
				enhead = t;
		}
		if(arg(a, 1) != "")
			emit(cur, "\\label{" + arg(a, 1) + "}");
	"section" or "subsection" or "subsubsection" or "section*" or "subsection*" =>
		# (an article's first section makes its title, if nothing has)
		if(macros != "book" && !titlemade && (title != "" || authors != nil))
			maketitle();
		blankline();
		block("\\" + name + "{" + textarg(arg(a, 0)) + "}");
		if(arg(a, 1) != "")
			emit(cur, "\\label{" + arg(a, 1) + "}");
	"p" or "PP" or "LP" =>
		paragraph();
	"quote" =>
		block("\\begin{quotation}");
	"endquote" =>
		block("\\end{quotation}");
		cur.noindent = 1;
	"epigraph" =>
		epigraph();
	"fn" =>
		note("fe", "\\footnote", "\\footnotetext");
	"en" =>
		haveendnotes = 1;
		if(enhead != ""){
			closefont(cur);
			attach(cur, "\\addtoendnotes{\\protect\\par\\protect\\medskip\\protect\\noindent\\protect\\textit{" + enhead + "}\\protect\\par\\protect\\smallskip}");
			enhead = "";
		}
		note("ee", "\\endnote", "\\endnotetext");
	"notes" =>
		blankline();
		block("\\chapter*{Notes}");
		emit(cur, "\\addcontentsline{toc}{chapter}{Notes}");
		emit(cur, "\\markboth{Notes}{Notes}");
		emit(cur, "\\theendnotes");
		haveendnotes = 1;
	"label" =>
		closefont(cur);
		attach(cur, "\\label{" + arg(a, 0) + "}");
	"figure" or "table" or "figure*" or "table*" =>
		blankline();
		infloat = name;
		floatlabel = arg(a, 0);
		if(suffix("*", name))
			block("\\begin{" + name + "}[tp]");
		else
			block("\\begin{" + name + "}[tbp]");
		emit(cur, "\\centering");
		floatat = nlines(cur);
	"caption" =>
		c := "\\caption{" + textarg(join(a, " ")) + "}" :: nil;
		if(floatlabel != "")
			c = "\\label{" + floatlabel + "}" :: c;
		closefont(cur);
		# a journal's table has its caption above it
		if(pdftex && prefix("table", infloat) && floatat > 0)
			insertat(cur, floatat, c);
		else
			for(c = rev(c); c != nil; c = tl c)
				emit(cur, hd c);
		cur.intext = 0;
	"alt" =>
		closefont(cur);
		t := textarg(join(a, " "));
		if(cls == "acm" && prefix("figure", infloat))
			emit(cur, "\\Description{" + t + "}");
		else
			emit(cur, "% alt: " + t);
	"endfigure" or "endtable" or "endfigure*" or "endtable*" =>
		block("\\end{" + infloat + "}");
		infloat = "";
		floatlabel = "";
	"list" =>
		blankline();
		env := "itemize";
		if(arg(a, 0) == "1" || arg(a, 0) == "a" || arg(a, 0) == "i")
			env = "enumerate";
		lists = env :: lists;
		block("\\begin{" + env + "}");
	"item" =>
		closefont(cur);
		if(arg(a, 0) != "")
			block("\\item[" + textarg(arg(a, 0)) + "]");
		else
			block("\\item");
	"endlist" =>
		if(lists != nil){
			block("\\end{" + hd lists + "}");
			lists = tl lists;
		}
		cur.noindent = 1;
	"image" =>
		havepics = 1;
		closefont(cur);
		f := arg(a, 0);
		o := "";
		if(arg(a, 1) != "")
			o = "width=" + dimen(arg(a, 1));
		if(arg(a, 2) != ""){
			if(o != "")
				o += ",";
			o += "height=" + dimen(arg(a, 2));
		}
		# (neither: its own size, as troff's; LaTeX's needs no options)
		if(o != "")
			o = "[" + o + "]";
		centrein("\\includegraphics" + o + "{" + f + "}");
	"url" or "link" =>
		# a URL (.url address [after]), or text a link to one (.link
		# address "text" [after]): hyperref's; IEEEtran's has none, the
		# address after the text
		haveurls = 1;
		closefont(cur);
		u := "\\url{" + urlesc(arg(a, 0)) + "}";
		after := arg(a, 1);
		if(name == "link"){
			if(cls == "ieee")
				u = textarg(arg(a, 1)) + " (" + u + ")";
			else
				u = "\\href{" + urlesc(arg(a, 0)) + "}{" + textarg(arg(a, 1)) + "}";
			after = arg(a, 2);
		}
		textline(cur, "");
		joinlast(cur, u + textarg(after));
	"appendix" =>
		# (IEEEtran's \appendix is one appendix with no title of its
		# own: \appendices letters sections with theirs)
		if(cls == "ieee")
			block("\\appendices");
		else
			block("\\appendix");
	"listoffigures" =>
		block("\\listoffigures");
	"listoftables" =>
		block("\\listoftables");
	"contents" =>
		block("\\tableofcontents");
	"cite" =>
		havecites = 1;
		closefont(cur);
		if(biblatex())
			citeattach(cur, cites("\\autocite", trim(rest)));
		else
			citeattach(cur, cites("\\cite", trim(rest)));
	"bibliography" =>
		havecites = 1;
		bibliography();
	"index" =>
		haveindex = 1;
		closefont(cur);
		attach(cur, "\\index{" + indexentry(join(a, " ")) + "}");
	"printindex" =>
		haveindex = 1;
		blankline();
		block("\\printindex");
	"EQ" =>
		display(a);
	"TS" =>
		havetables = 1;
		table();
	"PS" =>
		havepics = 1;
		picture(s, ".PE", "pic");
	"CB" =>
		havepics = 1;
		picture(s, ".CE", "chess");
	"char" or "fzoom" or "fspecial" or "fp" =>
		# a character's glyph, for troff; LaTeX's fonts have their own.
		# A picture's labels are set by troff, with them
		trprelude += s + "\n";
		closefont(cur);
		emit(cur, "% troff: " + s);
	"br" =>
		if(cur.intext && !cur.nf){
			closefont(cur);
			joinlast(cur, "\\newline");
		}
	"sp" =>
		d := "1\\baselineskip";
		if(arg(a, 0) != "")
			d = dimen(arg(a, 0));
		if(cur.nf){
			block("\\vspace{" + d + "}");
			cur.nfline = 0;
		}else{
			block("\\par\\vspace{" + d + "}");
			cur.noindent = 1;
		}
	"bp" =>
		block("\\clearpage");
	"ce" =>
		n := 1;
		if(arg(a, 0) != "")
			n = int arg(a, 0);
		if(n > 0)
			centre(n);
	"nf" =>
		if(!cur.nf){
			block("\\begin{flushleft}");
			cur.nf = 1;
			cur.nfline = 0;
		}
	"fi" =>
		if(cur.nf){
			cur.nf = 0;
			block("\\end{flushleft}");
			cur.noindent = 1;
		}
	"ft" =>
		setfont(cur, fontnamed(arg(a, 0)));
	"ds" or "as" =>
		dsreq(name, rest);
	"so" =>
		f := bufio->open(arg(a, 0), Bufio->OREAD);
		if(f == nil)
			warn(sys->sprint(".so %s: %r", arg(a, 0)));
		else
			inputs = ref Inp(f, arg(a, 0), 0) :: inputs;
	"code" =>
		# a program's text as typed: LaTeX's verbatim, troff's escapes undone
		block("\\begin{verbatim}");
		while((t := readline()) != nil && !prefix(".endcode", t))
			emit(cur, verbatim(t));
		block("\\end{verbatim}");
		cur.noindent = 1;
	"de" or "am" or "ig" =>
		if(name != "ig")
			warn("macro " + arg(a, 0) + " not written as LaTeX");
		end := "..";
		if(name == "ig" && arg(a, 0) != "")
			end = "." + arg(a, 0);
		closefont(cur);
		emit(cur, "% troff: " + s);
		while((t := readline()) != nil && trim(t) != end)
			emit(cur, "% " + t);
	"hw" =>
		block("\\hyphenation{" + join(a, " ") + "}");
	"pn" =>
		block("\\setcounter{page}{" + arg(a, 0) + "}");
	"papersize" =>
		case arg(a, 0) {
		"a4" =>	papersize = array[] of {"21cm", "29.7cm"};
		"a5" =>	papersize = array[] of {"14.8cm", "21cm"};
		"b5" =>	papersize = array[] of {"17.6cm", "25cm"};
		"letter" =>	papersize = array[] of {"8.5in", "11in"};
		* =>
			papersize[0] = dimen(arg(a, 0));
			papersize[1] = dimen(arg(a, 1));
		}
	"margins" =>
		for(k := 0; k < 4; k++)
			if(arg(a, k) != "")
				margins[k] = dimen(arg(a, k));
	"nr" =>
		if(arg(a, 0) == "book-ps")
			ptsize = arg(a, 1) + "pt";
	"ne" or "ti" or "in" or "ll" or "ad" or "na" or "nh" or "hy" or "ps" or "vs" or
	"ls" or "ns" or "rs" or "pl" or "po" or "ta" or "lg" or "tm" or "ev" or "ss" or
	"cs" or "ff" or "mtp" or "mte" or "mtpc" or "wo" or "mg" or "rules" or "kn" =>
		;
	* =>
		warn("." + name + " not written as LaTeX");
		closefont(cur);
		emit(cur, "% troff: " + s);
	}
}

# whether the citations are biblatex's (biber's), not BibTeX's (a journal's)
biblatex(): int
{
	return !pdftex;
}

# the database: -p's, or the source's stem.bib
bibfile(): string
{
	if(bib != "")
		return bib;
	b := srcname;
	for(i := len b - 1; i >= 0 && b[i] != '/'; i--)
		if(b[i] == '.'){
			b = b[0:i];
			break;
		}
	bib = b + ".bib";
	warn("citations, and no database (-p): " + bib + " is taken to be it");
	return bib;
}

# the references: biblatex's, or BibTeX's in the journal's style
bibliography()
{
	bibmade = 1;
	blankline();
	if(biblatex()){
		if(cls == "book")
			block("\\printbibliography[heading=bibintoc]");
		else
			block("\\printbibliography");
		return;
	}
	b := bibfile();
	if(suffix(".bib", b))
		b = b[0:len b - 4];
	else
		warn(b + " is not BibTeX's, as BibTeX needs");
	bst := "IEEEtran";
	if(cls == "acm")
		bst = "ACM-Reference-Format";
	block("\\bibliographystyle{" + bst + "}");
	emit(cur, "\\bibliography{" + b + "}");
}

# the title, as the class makes it: the authors, their affiliations and
# addresses, the abstract and keywords
maketitle()
{
	titlemade = 1;
	blankline();
	al: list of ref Author;
	for(l := authors; l != nil; l = tl l)
		al = hd l :: al;
	case cls {
	"book" =>
		t := title;
		if(subtitle != "")
			t += "\\\\[1ex]\\large " + subtitle;
		block("\\title{" + t + "}");
		emit(cur, "\\author{" + author + "}");
		emit(cur, "\\date{" + date + "}");
		emit(cur, "\\maketitle");
		if(abstract != ""){
			emit(cur, "\\begin{quotation}\\noindent\\textbf{Abstract.} " + abstract + "\\end{quotation}");
			abstract = "";
		}
	"ieee" =>
		ieeetitle(al);
	"acm" =>
		acmtitle(al);
	"memo" =>
		if(memokind == "report")
			articletitle(al);
		else
			memohead(al);
	* =>
		articletitle(al);
	}
	cur.noindent = 1;
}

articletitle(al: list of ref Author)
{
	t := title;
	if(subtitle != "")
		t += "\\\\[1ex]\\large " + subtitle;
	block("\\title{" + t + "}");
	a := "";
	for(; al != nil; al = tl al){
		au := hd al;
		if(a != "")
			a += "\n\\and ";
		a += au.name;
		if(au.affil != "")
			a += "\\\\ " + au.affil;
		if(au.loc != "")
			a += "\\\\ " + trim(au.loc + " " + au.ext);
		if(au.email != "")
			a += "\\\\ \\texttt{" + au.email + "}";
	}
	emit(cur, "\\author{" + a + "}");
	emit(cur, "\\date{" + date + "}");
	emit(cur, "\\maketitle");
	if(abstract != "" || keywords != ""){
		emit(cur, "\\begin{abstract}");
		if(abstract != "")
			emit(cur, abstract);
		if(keywords != "")
			emit(cur, "\\par\\medskip\\noindent\\textit{Keywords:} " + keywords);
		emit(cur, "\\end{abstract}");
	}
}

# IEEEtran's: in a journal, the authors' names in a line and where each
# is in a note (\thanks); at a conference, a block for each
ieeetitle(al: list of ref Author)
{
	t := title;
	if(subtitle != ""){
		if(t != "" && (suffix("?", t) || suffix("!", t) || suffix(":", t)))
			t += " " + subtitle;
		else
			t += ": " + subtitle;
	}
	block("\\title{" + t + "}");
	a := "";
	if(hasopt(clsopts, "conference")){
		for(; al != nil; al = tl al){
			au := hd al;
			if(a != "")
				a += "\n\\and\n";
			a += "\\IEEEauthorblockN{" + au.name + "}";
			w := au.affil;
			if(au.loc != "")
				w = join2(w, trim(au.loc + " " + au.ext), "\\\\ ");
			if(au.email != "")
				w = join2(w, au.email, "\\\\ ");
			if(w != "")
				a += "\n\\IEEEauthorblockA{" + w + "}";
		}
	}else{
		n := 0;
		for(l := al; l != nil; l = tl l)
			n++;
		thanks := "";
		k := 0;
		for(; al != nil; al = tl al){
			au := hd al;
			k++;
			if(k > 1 && k == n && n > 2)
				a += ", and ";
			else if(k > 1 && k == n)
				a += " and ";
			else if(k > 1)
				a += ", ";
			a += au.name;
			w := "";
			if(au.affil != "")
				w = au.name + " is with " + au.affil;
			if(au.email != ""){
				if(w == "")
					w = au.name + "'s e-mail is " + au.email;
				else
					w += " (e-mail: " + au.email + ")";
			}
			if(w != "")
				thanks += "\n\\thanks{" + w + ".}";
		}
		a += thanks;
	}
	emit(cur, "\\author{" + a + "}");
	if(date != "")
		emit(cur, "% date: " + date);
	emit(cur, "\\maketitle");
	if(abstract != ""){
		emit(cur, "\\begin{abstract}");
		emit(cur, abstract);
		emit(cur, "\\end{abstract}");
	}
	if(keywords != ""){
		emit(cur, "\\begin{IEEEkeywords}");
		emit(cur, keywords);
		emit(cur, "\\end{IEEEkeywords}");
	}
}

# acmart's: each author, the institution and address; the abstract and
# keywords before \maketitle
acmtitle(al: list of ref Author)
{
	block("\\title{" + title + "}");
	if(subtitle != "")
		emit(cur, "\\subtitle{" + subtitle + "}");
	for(; al != nil; al = tl al){
		au := hd al;
		emit(cur, "\\author{" + au.name + "}");
		# acmart wants the country: the affiliation's last part, after
		# a comma (.affil "Bell Laboratories, Murray Hill, USA")
		w := au.affil;
		if(au.loc != "")
			w = join2(w, trim(au.loc + " " + au.ext), ", ");
		# (and its city, the part before, if there are three)
		country: string;
		(w, country) = lastpart(w);
		city := "";
		if(country != "" && contains(w, ","))
			(w, city) = lastpart(w);
		if(country == ""){
			warn("acmart wants each affiliation's country: .affil's last part, after a comma");
			country = "[country]";
		}
		if(city != "")
			city = "\\city{" + city + "}";
		emit(cur, "\\affiliation{\\institution{" + w + "}" + city + "\\country{" + country + "}}");
		if(au.email != "")
			emit(cur, "\\email{" + au.email + "}");
	}
	if(date != "")
		emit(cur, "% date: " + date);
	if(abstract != ""){
		emit(cur, "\\begin{abstract}");
		emit(cur, abstract);
		emit(cur, "\\end{abstract}");
	}
	if(keywords != "")
		emit(cur, "\\keywords{" + keywords + "}");
	emit(cur, "\\maketitle");
}

# a technical memorandum's head, as -mmemo sets it: the organization at
# the right; the subject (and its case and file) at the left, the date,
# the authors and the number at the right; the kind below, across
memohead(al: list of ref Author)
{
	if(memoorg != ""){
		block("\\begin{flushright}");
		emit(cur, "\\textbf{\\large " + memoorg + "}");
		emit(cur, "\\end{flushright}");
		emit(cur, "\\vspace{0.3in}");
	}
	block("\\noindent\\begin{minipage}[t]{0.55\\textwidth}");
	emit(cur, "\\raggedright\\textit{\\small subject:} \\textbf{" + title + "}");
	if(subtitle != "")
		emit(cur, "\\\\ \\textbf{" + subtitle + "}");
	cf := "";
	if(memocase != "")
		cf = "Case " + memocase;
	if(memofile != "")
		cf = join2(cf, "File " + memofile, " --- ");
	if(cf != "")
		emit(cur, "\\\\[0.4ex] {\\small " + cf + "}");
	emit(cur, "\\end{minipage}\\hfill");
	emit(cur, "\\begin{minipage}[t]{0.4\\textwidth}");
	emit(cur, "\\raggedright");
	if(date != "")
		emit(cur, "\\textit{\\small date:} \\textbf{" + date + "}\\\\[0.5ex]");
	first := 1;
	for(; al != nil; al = tl al){
		au := hd al;
		if(first)
			emit(cur, "\\textit{\\small from:} \\textbf{" + au.name + "}\\\\");
		else
			emit(cur, "\\textbf{" + au.name + "}\\\\");
		w := trim(au.loc + " " + au.ext);
		if(w != "")
			emit(cur, "{\\small " + w + "}\\\\");
		first = 0;
	}
	if(memonumber != "")
		emit(cur, "[0.5ex]\\textit{\\small TM:} \\textbf{" + memonumber + "}");
	emit(cur, "\\end{minipage}");
	emit(cur, "\\begin{center}");
	emit(cur, "\\textbf{" + memotype + "}");
	emit(cur, "\\end{center}");
	if(abstract != ""){
		emit(cur, "\\begin{quote}");
		emit(cur, "\\small " + abstract);
		emit(cur, "\\end{quote}");
	}
}

# s's last part after a comma, and what is before it
lastpart(s: string): (string, string)
{
	for(i := len s - 1; i >= 0; i--)
		if(s[i] == ',')
			return (trim(s[0:i]), trim(s[i + 1:]));
	return (s, "");
}

join2(a, b, sep: string): string
{
	if(a == "")
		return b;
	if(b == "")
		return a;
	return a + sep + b;
}

# whether o (options separated by commas) has w
hasopt(o, w: string): int
{
	(nil, l) := sys->tokenize(o, ",");
	for(; l != nil; l = tl l)
		if(hd l == w)
			return 1;
	return 0;
}

# a block of the source's text (an abstract's), until end, as LaTeX's
captured(end: string): string
{
	o := cur;
	closefont(o);
	n := newout();
	cur = n;
	while((s := readline()) != nil){
		if(prefix(end, s))
			break;
		if(trim(s) == "")
			paragraph();
		else if(s[0] == '.' || s[0] == '\'')
			request(s);
		else
			textline(n, s);
	}
	closefont(n);
	cur = o;
	l := rev(n.l);
	while(l != nil && hd l == "")
		l = tl l;
	t := join(l, "\n");
	while(suffix("\n", t))
		t = t[0:len t - 1];
	return t;
}

# the lines written
nlines(o: ref Out): int
{
	n := 0;
	for(l := o.l; l != nil; l = tl l)
		n++;
	return n;
}

# lines l (the last first) put after the first at lines written
insertat(o: ref Out, at: int, l: list of string)
{
	top: list of string;
	for(k := nlines(o) - at; k > 0 && o.l != nil; k--){
		top = hd o.l :: top;
		o.l = tl o.l;
	}
	for(l = rev(l); l != nil; l = tl l)
		o.l = hd l :: o.l;
	for(; top != nil; top = tl top)
		o.l = hd top :: o.l;
}

# a blank line before a heading
blankline()
{
	closefont(cur);
	if(cur.l != nil && hd cur.l != "")
		emit(cur, "");
}

dsreq(name, rest: string)
{
	i := 0;
	while(i < len rest && (rest[i] == ' ' || rest[i] == '\t'))
		i++;
	j := i;
	while(j < len rest && rest[j] != ' ' && rest[j] != '\t')
		j++;
	n := rest[i:j];
	while(j < len rest && (rest[j] == ' ' || rest[j] == '\t'))
		j++;
	v := rest[j:];
	if(v != "" && v[0] == '"')
		v = v[1:];
	if(name == "as"){
		for(l := strs; l != nil; l = tl l)
			if((hd l).t0 == n){
				v = (hd l).t1 + v;
				break;
			}
	}
	strs = (n, v) :: strs;
}

# .ce n: n lines centred
centre(n: int)
{
	block("\\begin{center}");
	first := 1;
	while(n > 0 && (s := readline()) != nil){
		if(s != "" && (s[0] == '.' || s[0] == '\'')){
			unread(s);
			break;
		}
		if(!first)
			joinlast(cur, "\\\\");
		t := textarg(s);
		emit(cur, t);
		first = 0;
		n--;
	}
	block("\\end{center}");
	cur.noindent = 1;
}

# a footnote or endnote: its text, until .fe or .ee
note(end, cmd, textcmd: string)
{
	o := cur;
	closefont(o);
	marked := 0;
	if(cmd == "\\footnote"){
		marked = o.fnmarked;
		o.fnmarked = 0;
	}else{
		marked = o.enmarked;
		o.enmarked = 0;
	}
	n := newout();
	cur = n;
	innote++;
	while((s := readline()) != nil){
		if(len s > 1 && s[0] == '.' && trim(s[1:]) == end)
			break;
		if(trim(s) == "")
			paragraph();
		else if(s[0] == '.' || s[0] == '\'')
			request(s);
		else
			textline(n, s);
	}
	# (a note ending in a citation ends with a full stop)
	if(notecited && n.l != nil && hd n.l != "" && !suffix(".", hd n.l))
		n.l = (hd n.l + ".") :: tl n.l;
	closefont(n);
	cur = o;
	innote--;
	closeparen = 0;
	notecited = 0;
	body := join(rev(n.l), "\n");
	if(marked)
		cmd = textcmd;
	t := cmd + "{" + body + "}";
	if(o.cont && o.l != nil && hd o.l != "")
		joinlast(o, t);
	else
		emit(o, t);
	o.cont = 0;
	o.intext = 1;
}

# .epigraph text .attrib "source" .endepigraph
epigraph()
{
	haveepigraph = 1;
	o := cur;
	closefont(o);
	n := newout();
	cur = n;
	attrib := "";
	while((s := readline()) != nil){
		if(prefix(".endepigraph", s))
			break;
		if(prefix(".attrib", s)){
			attrib = "---~" + textarg(join(reqargs(s[7:]), " "));
			continue;
		}
		if(trim(s) == "")
			paragraph();
		else if(s[0] == '.' || s[0] == '\'')
			request(s);
		else
			textline(n, s);
	}
	closefont(n);
	cur = o;
	emit(o, "\\epigraph{" + join(rev(n.l), "\n") + "}{" + attrib + "}");
	o.noindent = 1;
}

# .index's entry: makeindex's, the text before its | (see{...} and the
# like) as LaTeX
indexentry(s: string): string
{
	for(i := 0; i < len s; i++){
		if(s[i] == '"'){
			i++;
			continue;
		}
		if(s[i] == '|')
			return textarg(s[0:i]) + s[i:];
	}
	return textarg(s);
}

#
# eqn's equations, as LaTeX's mathematics
#

# a display: .EQ [I|L|C] [label] ... .EN; one with mark, and those
# right after it with lineup, aligned (LaTeX's align)
display(a: list of string)
{
	(m, label, al) := readdisplay(a);
	if(m == "")
		return;
	closefont(cur);
	if(al){
		lines := m + " " + latextag(label, 1) :: nil;
		for(;;){
			s := readline();
			if(s == nil || !prefix(".EQ", s) || (len s > 3 && s[3] != ' ')){
				if(s != nil)
					unread(s);
				break;
			}
			(m2, l2, al2) := readdisplay(reqargs(s[3:]));
			if(!al2){
				emit(cur, "\\begin{align}");
				emitlines(rev(lines));
				emit(cur, "\\end{align}");
				lines = nil;
				onedisplay(m2, l2);
				break;
			}
			lines = m2 + " " + latextag(l2, 1) :: lines;
		}
		if(lines != nil){
			emit(cur, "\\begin{align}");
			emitlines(rev(lines));
			emit(cur, "\\end{align}");
		}
	}else
		onedisplay(m, label);
	cur.noindent = 1;
}

# a display's LaTeX, its label, and whether it marks or lines up
readdisplay(a: list of string): (string, string, int)
{
	if(a != nil && (hd a == "I" || hd a == "L" || hd a == "C"))
		a = tl a;
	label := join(a, " ");
	src := "";
	while((s := readline()) != nil && !prefix(".EN", s))
		src += s + "\n";
	ealigned = 0;
	m := trim(eqn(src, 1));
	if(m == "")	# delim, define: a picture's labels' too
		eqprelude += ".EQ\n" + src + ".EN\n";
	return (m, label, ealigned);
}

onedisplay(m, label: string)
{
	if(m == "")
		return;
	if(label != ""){
		emit(cur, "\\begin{equation}");
		emit(cur, m + " " + latextag(label, 0));
		emit(cur, "\\end{equation}");
	}else{
		emit(cur, "\\[");
		emit(cur, m);
		emit(cur, "\\]");
	}
}

# a label as LaTeX's \tag; in an align, none as \notag
latextag(label: string, inalign: int): string
{
	if(label == ""){
		if(inalign)
			return "\\notag";
		return "";
	}
	if(len label > 2 && label[0] == '(' && label[len label - 1] == ')')
		return "\\tag{" + label[1:len label - 1] + "}";
	return "\\tag*{" + label + "}";
}

emitlines(l: list of string)
{
	for(; l != nil; l = tl l){
		if(tl l != nil)
			emit(cur, hd l + " \\\\");
		else
			emit(cur, hd l);
	}
}

# what eqn reads: the equation, and a define's body before the rest
Src: adt {
	s:	string;
	p:	int;
};
esrc: list of ref Src;
epeek: string;
epeeked := 0;
ecount := 0;
edisplay := 0;
eexpand := 0;
edefs: list of (string, string);
emarked := 0;		# a mark or lineup read: & next
ealigned := 0;		# one read in this display

FROM, SUB, NOLIM: con 1 << iota;	# NOLIM: no from or to of its own (a brace's)

eqn(s: string, disp: int): string
{
	esrc = ref Src(s, 0) :: nil;
	epeeked = 0;
	edisplay = disp;
	eexpand = 0;
	(r, nil) := elist(nil);
	return trim(r);
}

# a character of what is read, or -1
egetc(): int
{
	while(esrc != nil){
		t := hd esrc;
		if(t.p < len t.s)
			return t.s[t.p++];
		esrc = tl esrc;
	}
	return -1;
}

eungetc()
{
	if(esrc != nil)
		(hd esrc).p--;
}

eseparates(c: int): int
{
	return c == ' ' || c == '\n' || c == '\t' || c == '{' || c == '}' ||
		c == '~' || c == '^' || c == '"' || c == -1;
}

# a token: a word, { } ~ ^ a tab, or a quoted string ("text, its quote
# kept); a word defined, its definition read instead
elex(expand: int): string
{
	for(;;){
		c := egetc();
		while(c == ' ' || c == '\n')
			c = egetc();
		if(c < 0)
			return nil;
		case c {
		'\t' =>	return "\t";
		'{' =>	return "{";
		'}' =>	return "}";
		'~' =>	return "~";
		'^' =>	return "^";
		'"' =>
			s := "\"";
			while((c = egetc()) >= 0 && c != '"'){
				if(c == '\\'){
					c2 := egetc();
					if(c2 == '"'){
						s[len s] = '"';
						continue;
					}
					if(c2 >= 0)
						eungetc();
				}
				s[len s] = c;
			}
			return s;
		}
		s := "";
		while(!eseparates(c)){
			s[len s] = c;
			c = egetc();
		}
		if(c >= 0)
			eungetc();
		if(expand && eexpand < 1000)
			for(l := edefs; l != nil; l = tl l)
				if((hd l).t0 == s){
					eexpand++;
					esrc = ref Src((hd l).t1, 0) :: esrc;
					s = nil;
					break;
				}
		if(s != nil)
			return s;
	}
}

epk(): string
{
	if(!epeeked){
		epeek = elex(1);
		epeeked = 1;
	}
	return epeek;
}

enext(): string
{
	t := epk();
	epeeked = 0;
	ecount++;
	return t;
}

# a define's body: between the character after its name and that again
erawdelim(): string
{
	c := egetc();
	while(c == ' ' || c == '\t' || c == '\n')
		c = egetc();
	if(c < 0)
		return "";
	d := c;
	s := "";
	while((c = egetc()) >= 0 && c != d)
		s[len s] = c;
	return s;
}

# eqn's statements: define, delim, gsize and the rest; what they set
# here (delim, define) set; mark and lineup put aside
ecommands()
{
	for(;;){
		case epk() {
		"define" or "ndefine" or "tdefine" =>
			t := enext();
			epeeked = 0;
			name := elex(0);
			body := erawdelim();
			if(t != "ndefine")
				edefs = (name, body) :: edefs;
		"delim" =>
			enext();
			d := elex(0);
			if(d == "off" || len d < 2)
				dl1 = dl2 = 0;
			else{
				dl1 = d[0];
				dl2 = d[1];
			}
		"gsize" or "gfont" or "grfont" or "gbfont" =>
			enext();
			elex(0);
		"set" or "chartype" or "breakcost" =>
			enext();
			elex(0);
			elex(0);
		"bracketpieces" =>
			enext();
			for(k := 0; k < 5; k++)
				elex(0);
		"bracketsizes" =>
			enext();
			elex(0);
			n := int elex(0);
			for(k := 0; k < n && k < 100; k++)
				elex(0);
		"mark" or "lineup" =>
			# where displays are aligned: LaTeX's & (display())
			enext();
			emarked = ealigned = 1;
		"gsfont" =>
			enext();
			elex(0);
		"accent" or "accentpos" or "mathital" or "italcorr" or "bracesizes" =>
			# (eqnrc's, mkfn -M's: the font's, nothing for LaTeX)
			t := enext();
			if(t == "accent" || t == "bracesizes")
				elex(0);
			n := int elex(0);
			per := 2;
			if(t == "accent")
				per = 3;
			for(k := 0; k < n * per && k < 1000; k++)
				elex(0);
		"bracepieces" =>
			enext();
			for(k := 0; k < 10; k++)
				elex(0);
		* =>
			return;
		}
	}
}

# boxes, until one of stops; which ended them
elist(stops: list of string): (string, string)
{
	r := "";
	for(;;){
		ecommands();
		if(emarked){
			r += " &";
			emarked = 0;
		}
		t := epk();
		if(t == nil)
			return (r, nil);
		for(l := stops; l != nil; l = tl l)
			if(hd l == t){
				enext();
				return (r, t);
			}
		n := ecount;
		b := ebox();
		if(b != ""){
			if(r != "" && r[len r - 1] != ' ')
				r += " ";
			r += b;
		}
		if(ecount == n && epk() != nil){
			sys->fprint(stderr, "book2tex: eqn: %s out of place (%s line %d)\n", epk(), inname(), inline());
			enext();
		}
	}
}

ebox(): string
{
	b := eleft(0);
	while(epk() == "over" || epk() == "choose"){
		f := "\\frac{";
		if(enext() == "choose")	# (eqnrc's: TeX's \\binom)
			f = "\\binom{";
		d := eleft(0);
		b = f + b + "}{" + d + "}";
	}
	return b;
}

# words that do not begin a box
estructural(t: string): int
{
	case t {
	"over" or "choose" or "sub" or "sup" or "from" or "to" or "above" or "right" or "}" or
	"ccol" or "lcol" or "rcol" or "col" =>
		return 1;
	}
	return 0;
}

eleft(flg: int): string
{
	ecommands();
	t := epk();
	if(t == nil)
		return "";
	case t {
	"~" =>	enext(); return "\\ ";
	"^" =>	enext(); return "\\,";
	"\t" =>	enext(); return "\\quad ";
	}
	font := "";
	dx := 0;
	dy := 0;
	for(;;){
		case epk() {
		"fat" =>	enext();
		"roman" =>	enext(); font = "R";
		"italic" =>	enext(); font = "I";
		"bold" =>	enext(); font = "B";
		"font" =>
			enext();
			font = "R";
			case enext() {
			"I" or "2" =>	font = "I";
			"B" or "3" =>	font = "B";
			"BI" or "4" =>	font = "BI";
			"CW" or "CR" or "C" or "TT" =>	font = "TT";
			}
		"size" =>	enext(); enext();
		"fwd" =>	enext(); dx += int enext();
		"back" =>	enext(); dx -= int enext();
		"down" =>	enext(); dy += int enext();
		"up" =>	enext(); dy -= int enext();
		* =>
			break;
		}
		if(epk() == nil)
			break;
		case epk() {
		"fat" or "roman" or "italic" or "bold" or "font" or "size" or "fwd" or "back" or "down" or "up" =>
			continue;
		}
		break;
	}
	core := "";
	quoted := 0;
	t = epk();
	if(t == nil)
		;
	else if(t == "~" || t == "^" || t == "\t"){
		enext();
		case t {
		"~" =>	core = "\\ ";
		"^" =>	core = "\\,";
		* =>	core = "\\quad ";
		}
	}else if(t == "sqrt"){
		enext();
		core = "\\sqrt{" + eleft(0) + "}";
	}else if(t == "root"){
		enext();
		n := eleft(0);
		core = "\\sqrt[" + n + "]{" + eleft(0) + "}";
	}else if(t == "overbrace" || t == "underbrace"){
		enext();
		core = "\\" + t + "{" + eleft(NOLIM) + "}";
	}else if(t == "strut"){
		enext();
		core = "\\strut";
	}else if(t == "displaystyle" || t == "textstyle"){
		enext();
		core = "{\\" + t + " " + eleft(flg) + "}";
	}else if(t == "type"){
		enext();
		enext();
		if(epk() == "icorr"){	# an operator's italic correction: LaTeX's font has it
			enext();
			enext();
		}
		core = eleft(flg);
	}else if(t == "pile" || t == "cpile"){
		core = epile("c");
	}else if(t == "lpile"){
		core = epile("l");
	}else if(t == "rpile"){
		core = epile("r");
	}else if(t == "matrix"){
		core = ematrix();
	}else if(t == "vcenter"){
		enext();
		core = eleft(flg);
	}else if(t == "ifdisplay"){
		enext();
		a := eleft(flg);
		b := eleft(flg);
		if(edisplay)
			core = a;
		else
			core = b;
	}else if(t == "{"){
		enext();
		(l, nil) := elist("}" :: nil);
		core = "{" + l + "}";
	}else if(t == "left"){
		enext();
		ld := edelim(enext(), 0);
		(l, st) := elist("right" :: nil);
		rd := ".";
		if(st != nil && epk() != nil)
			rd = edelim(enext(), 1);
		core = "\\left" + ld + " " + l + " \\right" + rd;
	}else if(!estructural(t)){
		enext();
		if(t[0] == '"'){
			core = estring(t[1:], font);
			quoted = 1;
		}else
			core = eword(t);
	}
	if(font != "" && !quoted && core != "")
		core = efont(font, core);
	if(dx)
		core = "\\hspace{" + em(dx) + "}" + core;
	if(dy)
		core = "\\raisebox{" + em(-dy) + "}{$" + core + "$}";
	for(;;){
		a := "";
		case epk() {
		"dyad" =>	a = "\\overleftrightarrow";
		"bar" =>	# (over one glyph an accent, as eqnrc sets it)
			a = "\\overline";
			if(esingle(core))
				a = "\\bar";
		"under" =>	a = "\\underline";
		"vec" =>
			a = "\\vec";
			if(!esingle(core))
				a = "\\overrightarrow";
		"tilde" =>
			a = "\\tilde";
			if(!esingle(core))
				a = "\\widetilde";
		"hat" =>
			a = "\\hat";
			if(!esingle(core))
				a = "\\widehat";
		"dot" =>	a = "\\dot";
		"dotdot" =>	a = "\\ddot";
		}
		if(a == "")
			break;
		enext();
		core = a + "{" + core + "}";
	}
	subs, sups, froms, tos: string;
	if(epk() == "sub"){
		enext();
		subs = eleft(SUB);
	}
	if((subs != nil || !(flg & SUB)) && epk() == "sup"){
		enext();
		sups = eleft(0);
	}
	if(subs != nil || sups != nil){
		core = ebrace(core);
		if(subs != nil)
			core += "_{" + subs + "}";
		if(sups != nil)
			core += "^{" + sups + "}";
	}
	if(!(flg & NOLIM) && epk() == "from"){
		enext();
		froms = eleft(FROM);
	}
	if(!(flg & NOLIM) && (froms != nil || !(flg & FROM)) && epk() == "to"){
		enext();
		tos = eleft(0);
	}
	if(froms != nil || tos != nil){
		# a big operator's limits, and a brace's label, as _ and ^
		bigop := 0;
		case core {
		"\\sum" or "\\prod" or "\\bigcup" or "\\bigcap" or "\\lim" or "\\max" or "\\min" or "\\int" or "\\coprod" or
		"\\iint" or "\\iiint" or "\\oint" or "\\oiint" or "\\oiiint" or "\\bigvee" or "\\bigwedge" or
		"\\bigodot" or "\\bigoplus" or "\\bigotimes" or "\\biguplus" or "\\bigsqcup" =>
			bigop = 1;
		}
		if(len core > 12 && (core[0:11] == "\\overbrace{" || core[0:12] == "\\underbrace{"))
			bigop = 1;
		case bigop {
		1 =>
			if(froms != nil)
				core += "_{" + froms + "}";
			if(tos != nil)
				core += "^{" + tos + "}";
		* =>
			if(tos != nil)
				core = "\\overset{" + tos + "}{" + core + "}";
			if(froms != nil)
				core = "\\underset{" + froms + "}{" + core + "}";
		}
	}
	return core;
}

# one character, or one command: needs no braces
esingle(s: string): int
{
	if(len s == 1)
		return 1;
	if(len s < 2 || s[0] != '\\')
		return 0;
	for(i := 1; i < len s; i++)
		if(!isalpha(s[i]))
			return 0;
	return 1;
}

ebrace(s: string): string
{
	if(s == "")
		return "{}";
	if(esingle(s))
		return s;
	return "{" + s + "}";
}

em(n: int): string
{
	s := "";
	if(n < 0){
		s = "-";
		n = -n;
	}
	return s + sys->sprint("%d.%.2d", n / 100, n % 100) + "em";
}

efont(f, s: string): string
{
	case f {
	"R" =>	return "\\mathrm{" + s + "}";
	"I" =>	return "\\mathit{" + s + "}";
	"B" =>
		if(pdftex)
			return "\\mathbf{" + s + "}";
		return "\\symbf{" + s + "}";
	"BI" =>
		if(pdftex)
			return "\\boldsymbol{" + s + "}";
		return "\\symbfit{" + s + "}";
	"TT" =>	return "\\mathtt{" + s + "}";
	}
	return s;
}

# quoted text: eqn's italic, unless roman or bold
estring(s, font: string): string
{
	if(s == "")
		return "{}";
	# delimiters in the text are its own
	(d1, d2) := (dl1, dl2);
	dl1 = dl2 = 0;
	t := textarg(s);
	(dl1, dl2) = (d1, d2);
	case font {
	"R" =>	return "\\textrm{" + t + "}";
	"B" =>	return "\\textbf{" + t + "}";
	"BI" =>	return "\\textbf{\\textit{" + t + "}}";
	"TT" =>	return "\\texttt{" + t + "}";
	}
	return "\\textit{" + t + "}";
}

# left's or right's delimiter
edelim(t: string, right: int): string
{
	if(t != nil && t[0] == '"')
		t = t[1:];
	case t {
	"(" or ")" or "[" or "]" or "|" or "/" =>
		return t;
	"{" =>	return "\\{";
	"}" =>	return "\\}";
	"<" or "\\(la" =>	return "\\langle";
	">" or "\\(ra" =>	return "\\rangle";
	"floor" =>
		if(right)
			return "\\rfloor";
		return "\\lfloor";
	"ceiling" =>
		if(right)
			return "\\rceil";
		return "\\lceil";
	"\\(lf" =>	return "\\lfloor";
	"\\(rf" =>	return "\\rfloor";
	"\\(lc" =>	return "\\lceil";
	"\\(rc" =>	return "\\rceil";
	"||" or "\\(br" =>	return "\\|";
	}
	return ".";
}

# pile { a above b ... }
epile(align: string): string
{
	enext();
	if(epk() == "{")
		enext();
	rows: list of string;
	for(;;){
		(l, st) := elist("above" :: "}" :: nil);
		rows = l :: rows;
		if(st != "above")
			break;
	}
	return "\\begin{array}{" + align + "}" + join(rev(rows), " \\\\ ") + "\\end{array}";
}

# matrix { ccol { a above b } lcol { ... } }
ematrix(): string
{
	enext();
	# (eqn's spacing between columns, and each column's between rows:
	# columns pulled together, rcol then lcol, are aligned equations)
	colspace := 0;
	if(isnum(epk()))
		colspace = int enext();
	if(epk() == "{")
		enext();
	aligns := "";
	cols: list of list of string;
	nrows := 0;
	for(;;){
		t := epk();
		if(t == nil)
			break;
		if(t == "}"){
			enext();
			break;
		}
		al := "";
		case t {
		"ccol" or "col" =>	al = "c";
		"lcol" =>	al = "l";
		"rcol" =>	al = "r";
		}
		enext();
		if(al == ""){
			sys->fprint(stderr, "book2tex: eqn: %s out of place in a matrix (%s line %d)\n", t, inname(), inline());
			continue;
		}
		if(isnum(epk()))
			enext();
		if(epk() == "{")
			enext();
		col: list of string;
		n := 0;
		for(;;){
			(l, st) := elist("above" :: "}" :: nil);
			col = l :: col;
			n++;
			if(st != "above")
				break;
		}
		if(n > nrows)
			nrows = n;
		cols = rev(col) :: cols;
		aligns += al;
	}
	acols := array[len cols] of list of string;
	k := len cols;
	for(; cols != nil; cols = tl cols)
		acols[--k] = hd cols;
	rows: list of string;
	for(r := 0; r < nrows; r++){
		cells: list of string;
		for(c := 0; c < len acols; c++){
			v := "";
			if(acols[c] != nil){
				v = hd acols[c];
				acols[c] = tl acols[c];
			}
			cells = v :: cells;
		}
		rows = join(rev(cells), " & ") :: rows;
	}
	if(aligns == "rl" && colspace < 0)
		return "\\begin{aligned}" + join(rev(rows), " \\\\ ") + "\\end{aligned}";
	return "\\begin{array}{" + aligns + "}" + join(rev(rows), " \\\\ ") + "\\end{array}";
}

# whether an eqn word is a number (a matrix's spacing)
isnum(t: string): int
{
	if(t == nil)
		return 0;
	i := 0;
	if(t[0] == '-' || t[0] == '+')
		i = 1;
	if(i >= len t)
		return 0;
	for(; i < len t; i++)
		if(t[i] < '0' || t[i] > '9')
			return 0;
	return 1;
}

# eqn's words, and the characters operators are made of
ekw(w: string): (string, int)
{
	case w {
	"alpha" or "beta" or "gamma" or "delta" or "epsilon" or "zeta" or "eta" or
	"theta" or "iota" or "kappa" or "lambda" or "mu" or "nu" or "xi" or "pi" or
	"rho" or "sigma" or "tau" or "upsilon" or "phi" or "chi" or "psi" or "omega" =>
		return ("\\" + w, 1);
	"omicron" =>	return ("o", 1);
	"GAMMA" or "DELTA" or "THETA" or "LAMBDA" or "XI" or "PI" or "SIGMA" or
	"UPSILON" or "PHI" or "PSI" or "OMEGA" =>
		return ("\\" + w[0:1] + lower(w[1:]), 1);
	"ALPHA" =>	return ("\\mathrm{A}", 1);
	"BETA" =>	return ("\\mathrm{B}", 1);
	"CHI" =>	return ("\\mathrm{X}", 1);
	"EPSILON" =>	return ("\\mathrm{E}", 1);
	"ETA" =>	return ("\\mathrm{H}", 1);
	"IOTA" =>	return ("\\mathrm{I}", 1);
	"KAPPA" =>	return ("\\mathrm{K}", 1);
	"MU" =>	return ("\\mathrm{M}", 1);
	"NU" =>	return ("\\mathrm{N}", 1);
	"OMICRON" =>	return ("\\mathrm{O}", 1);
	"RHO" =>	return ("\\mathrm{P}", 1);
	"TAU" =>	return ("\\mathrm{T}", 1);
	"ZETA" =>	return ("\\mathrm{Z}", 1);
	"sin" or "cos" or "tan" or "sinh" or "cosh" or "tanh" or "coth" or "det" or
	"exp" or "lim" or "ln" or "log" or "max" or "min" =>
		return ("\\" + w, 1);
	"arc" =>	return ("\\mathrm{arc}", 1);
	"Im" or "Re" =>	return ("\\operatorname{" + w + "}", 1);
	"and" or "for" or "if" =>	return ("\\mathrm{" + w + "}", 1);
	"inf" or "infinity" =>	return ("\\infty", 1);
	"partial" =>	return ("\\partial", 1);
	"del" or "grad" =>	return ("\\nabla", 1);
	"times" =>	return ("\\times", 1);
	"cdot" =>	return ("\\cdot", 1);
	"approx" =>	return ("\\approx", 1);
	"half" =>	return ("\\frac{1}{2}", 1);
	"prime" =>	return ("{}'", 1);	# its own, after a superscript too
	"nothing" =>	return ("", 1);
	"dollar" =>	return ("\\$", 1);
	"sum" =>	return ("\\sum", 1);
	"int" =>	return ("\\int", 1);
	"prod" =>	return ("\\prod", 1);
	"union" =>	return ("\\bigcup", 1);
	"inter" =>	return ("\\bigcap", 1);
	# eqnrc's, as mkfn -M defines them
	"coprod" or "iint" or "iiint" or "oint" or "oiint" or "oiiint" or "bigcup" or
	"bigcap" or "bigvee" or "bigwedge" or "bigodot" or "bigoplus" or "bigotimes" or
	"biguplus" or "bigsqcup" or "cdots" or "ldots" or "vdots" or "ddots" or "nabla" or "hbar" =>
		return ("\\" + w, 1);
	}
	return (nil, 0);
}

lower(s: string): string
{
	r := "";
	for(i := 0; i < len s; i++){
		c := s[i];
		if(c >= 'A' && c <= 'Z')
			c += 'a' - 'A';
		r[len r] = c;
	}
	return r;
}

eops := array[] of {
	(",...,", ",\\ldots,"), ("...", "\\dots "), ("<=", "\\le "), (">=", "\\ge "),
	("==", "\\equiv "), ("!=", "\\ne "), ("->", "\\to "), ("<-", "\\gets "),
	("+-", "\\pm "), ("<<", "\\ll "), (">>", "\\gg "), (":=", "\\mathrel{:}= "),
};

# a word of an equation
eword(w: string): string
{
	(m, ok) := ekw(w);
	if(ok)
		return m;
	r := "";
	i := 0;
	Next:
	while(i < len w){
		c := w[i];
		if(c == '\\' && i + 1 < len w){
			(t, n) := mescape(w, i);
			r += t;
			i = n;
			continue;
		}
		for(k := 0; k < len eops; k++){
			(op, tex) := eops[k];
			if(len w - i >= len op && w[i:i + len op] == op){
				r += tex;
				i += len op;
				continue Next;
			}
		}
		if(isalpha(c)){
			j := i;
			while(j < len w && isalpha(w[j]))
				j++;
			run := w[i:j];
			(m, ok) = ekw(run);
			if(ok && run != "if" && run != "for" && run != "and")
				r += m + " ";
			else
				r += run;
			i = j;
			continue;
		}
		if(c >= 16r80){
			j := i;
			while(j < len w && w[j] >= 16r80)
				j++;
			if(j - i == 1)
				r += w[i:j];
			else
				r += "\\textit{" + w[i:j] + "}";
			i = j;
			continue;
		}
		case c {
		'#' or '$' or '%' or '&' or '_' =>
			r += "\\" + ch(c);
		* =>
			r += ch(c);
		}
		i++;
	}
	return trim(r);
}

# an escape in an equation
mescape(s: string, i: int): (string, int)
{
	c := s[i + 1];
	i += 2;
	case c {
	'(' or '[' =>
		(n, e) := escname(s, i - 1);
		return (mchar(n), e);
	'e' or '\\' =>
		return ("\\backslash ", i);
	' ' =>
		return ("\\ ", i);
	'|' or '^' =>
		return ("\\,", i);
	'f' =>
		(nil, e) := escname(s, i);
		return ("", e);
	's' =>
		if(i < len s && (s[i] == '+' || s[i] == '-'))
			i++;
		while(i < len s && isdigit(s[i]))
			i++;
		return ("", i);
	'-' =>
		return ("-", i);
	}
	return ("", i);
}

# a character troff names, in an equation
mchar(n: string): string
{
	case n {
	"mu" =>	return "\\times ";
	"mi" =>	return "-";
	"pl" =>	return "+";
	"eq" =>	return "=";
	"<=" =>	return "\\le ";
	">=" =>	return "\\ge ";
	"!=" =>	return "\\ne ";
	"+-" =>	return "\\pm ";
	"->" =>	return "\\to ";
	"<-" =>	return "\\gets ";
	"if" =>	return "\\infty ";
	"pd" =>	return "\\partial ";
	"gr" =>	return "\\nabla ";
	"sr" =>	return "\\surd ";
	"is" =>	return "\\int ";
	"su" =>	return "\\sum ";
	"pr" =>	return "\\prod ";
	"cu" =>	return "\\cup ";
	"ca" =>	return "\\cap ";
	"mo" =>	return "\\in ";
	"es" =>	return "\\emptyset ";
	"sb" =>	return "\\subset ";
	"sp" =>	return "\\supset ";
	"ib" =>	return "\\subseteq ";
	"ip" =>	return "\\supseteq ";
	"ap" =>	return "\\sim ";
	"~~" =>	return "\\approx ";
	"==" =>	return "\\equiv ";
	"de" =>	return "^{\\circ}";
	"fm" =>	return "'";
	"c." =>	return "\\cdot ";
	"**" =>	return "*";
	"br" or "or" =>	return "|";
	"lf" =>	return "\\lfloor ";
	"rf" =>	return "\\rfloor ";
	"lc" =>	return "\\lceil ";
	"rc" =>	return "\\rceil ";
	"la" =>	return "\\langle ";
	"ra" =>	return "\\rangle ";
	}
	t := tchar(n);
	case t {
	"---" =>	return "\\text{---}";
	"--" =>	return "\\text{--}";
	"``" or "''" or "`" =>	return "\\text{" + t + "}";
	}
	return t;
}

#
# tbl's tables, as tabulars
#

# a column's format: its key letter, font, rules before it
Fmt: adt {
	key:	int;
	font:	int;
	bars:	int;
	after:	int;	# rules after it, the last column's
};

table()
{
	closefont(cur);
	tab := '\t';
	centred := 0;
	box := 0;
	allbox := 0;
	vr := 0;	# vrules: its vertical rules drawn, as tbl draws them
	s := readline();
	if(s == nil)
		return;
	# the options, ending in ;
	if(suffix(";", trim(s))){
		o := lower(s);
		if(contains(o, "center") || contains(o, "centre"))
			centred = 1;
		if(contains(o, "allbox"))
			allbox = 1;
		else if(contains(o, "doublebox") || contains(o, "doubleframe"))
			box = 2;
		else if(contains(o, "box") || contains(o, "frame"))
			box = 1;
		if(contains(o, "vrules"))
			vr = 1;
		k := strindex(o, "tab(");
		if(k >= 0 && k + 4 < len s)
			tab = s[k + 4];
		s = readline();
	}
	(fmts, s2) := tblformats(s);
	s = s2;
	ncols := 0;
	for(fl := fmts; fl != nil; fl = tl fl)
		if(len hd fl > ncols)
			ncols = len hd fl;
	if(ncols == 0)
		ncols = 1;
	# the rows: cells, or a rule (nil, its kind)
	rows: list of (array of string, int);
	rowfmt: list of array of ref Fmt;
	fl = fmts;
	textcol := array[ncols] of {* => 0};
	for(; s != nil && !prefix(".TE", s); s = readline()){
		if(prefix(".T&", s)){
			(nf, s3) := tblformats(readline());
			if(nf != nil)
				fl = nf;
			unread(s3);
			continue;
		}
		if(s != "" && (s[0] == '.' || s[0] == '\''))
			continue;
		t := trim(s);
		if(t == "_" || t == "-"){
			rows = (nil, 1) :: rows;
			rowfmt = nil :: rowfmt;
			continue;
		}
		if(t == "="){
			rows = (nil, 2) :: rows;
			rowfmt = nil :: rowfmt;
			continue;
		}
		# a format all rules is a rule of its own
		while(fl != nil && tl fl != nil && allrules(hd fl)){
			rows = (nil, rulekind(hd fl)) :: rows;
			rowfmt = nil :: rowfmt;
			fl = tl fl;
		}
		cells := tblcells(s, tab);
		f: array of ref Fmt;
		if(fl != nil){
			f = hd fl;
			if(tl fl != nil)
				fl = tl fl;
		}
		for(k := 0; k < len cells && k < ncols; k++)
			if(cells[k] != "" && cells[k][0] == '\u0001'){
				cells[k] = cells[k][1:];
				textcol[k] = 1;
			}
		rows = (cells, 0) :: rows;
		rowfmt = f :: rowfmt;
	}
	# the columns' formats, from the first
	# the columns as the last format has them, which the most rows take
	first: array of ref Fmt;
	for(fl = fmts; fl != nil; fl = tl fl)
		first = hd fl;
	spec := "";
	for(c := 0; c < ncols; c++){
		b := 0;
		if(first != nil && c < len first)
			b = first[c].bars;
		if(allbox || box && c == 0)
			b = box + allbox;
		if(vr)
			spec += bars(b);
		key := 'l';
		if(first != nil && c < len first)
			key = first[c].key;
		if(textcol[c])
			spec += "p{" + sys->sprint("%.2f", 0.8 / real ncols) + "\\linewidth}";
		else
			spec += align(key);
	}
	if(!vr)
		;
	else if(allbox || box)
		spec += bars(box + allbox);
	else if(first != nil && len first > 0)
		spec += bars(first[len first - 1].after);
	if(infloat != "")
		;
	else if(centred)
		emit(cur, "\\begin{center}");
	else
		emit(cur, "\\par\\noindent");
	emit(cur, "\\begin{tabular}{" + spec + "}");
	if(box || allbox)
		emit(cur, hrule(vr, box + allbox, 1, 0));
	rl := rev2(rows);
	ff := revf(rowfmt);
	firstrow := 1;
	for(; rl != nil; rl = tl rl){
		(cells, rule) := hd rl;
		f := hd ff;
		ff = tl ff;
		if(cells == nil){
			emit(cur, hrule(vr, rule, firstrow && !box && !allbox, tl rl == nil && !box && !allbox));
			firstrow = 0;
			continue;
		}
		firstrow = 0;
		line := "";
		k := 0;
		while(k < ncols){
			key := 'l';
			font := R;
			if(f != nil && k < len f){
				key = f[k].key;
				font = f[k].font;
			}
			v := "";
			if(k < len cells)
				v = cells[k];
			span := 1;
			while(k + span < ncols && f != nil && k + span < len f && f[k + span].key == 's')
				span++;
			cell := "";
			tv := trim(v);
			if(key == '^' || key == '_' || key == '-' || key == '=' || key == 's')
				cell = "";
			else if(tv == "\\_" || tv == "_" || tv == "=")
				cell = "\\hrulefill";
			else{
				cell = textarg(v);
				if(font == B)
					cell = "\\textbf{" + cell + "}";
				else if(font == I)
					cell = "\\emph{" + cell + "}";
				else if(font == BI)
					cell = "\\textbf{\\emph{" + cell + "}}";
			}
			fk := 'l';
			if(first != nil && k < len first)
				fk = first[k].key;
			if(span > 1 || align(key) != align(fk) && key != '^' && key != 's' && !textcol[k]){
				lb := "";
				rb := "";
				if(k == 0 && vr)
					lb = bars(box + allbox);
				if(vr && (allbox || k + span == ncols && box))
					rb = bars(box + allbox);
				cell = "\\multicolumn{" + string span + "}{" + lb + align(key) + rb + "}{" + cell + "}";
			}
			if(k > 0)
				line += " & ";
			line += cell;
			k += span;
		}
		line += " \\\\";
		if(allbox && tl rl != nil && (hd tl rl).t0 != nil)
			line += " " + hrule(vr, 1, 0, 0);
		emit(cur, line);
	}
	if(box || allbox)
		emit(cur, hrule(vr, box + allbox, 0, 1));
	emit(cur, "\\end{tabular}");
	if(infloat != "")
		;
	else if(centred)
		emit(cur, "\\end{center}");
	else
		emit(cur, "\\par");
	cur.intext = 0;
	cur.noindent = 1;
}

bars(n: int): string
{
	s := "";
	while(n-- > 0)
		s += "|";
	return s;
}

# a horizontal rule: with the vertical ones, \hline, to meet them;
# without, booktabs' (its top, middle and bottom)
hrule(vr, n, top, bottom: int): string
{
	if(vr)
		return hline(n);
	if(top)
		return "\\toprule";
	if(bottom)
		return "\\bottomrule";
	if(n >= 2)
		return "\\midrule[\\heavyrulewidth]";
	return "\\midrule";
}

hline(n: int): string
{
	if(n >= 2)
		return "\\hline\\hline";
	return "\\hline";
}

align(key: int): string
{
	case key {
	'r' or 'n' =>	return "r";
	'c' =>	return "c";
	}
	return "l";
}

allrules(f: array of ref Fmt): int
{
	if(f == nil || len f == 0)
		return 0;
	for(i := 0; i < len f; i++)
		if(f[i].key != '_' && f[i].key != '-' && f[i].key != '=')
			return 0;
	return 1;
}

rulekind(f: array of ref Fmt): int
{
	if(f[0].key == '=')
		return 2;
	return 1;
}

contains(s, t: string): int
{
	return strindex(s, t) >= 0;
}

strindex(s, t: string): int
{
	for(i := 0; i + len t <= len s; i++)
		if(s[i:i + len t] == t)
			return i;
	return -1;
}

rev2(l: list of (array of string, int)): list of (array of string, int)
{
	r: list of (array of string, int);
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

revf(l: list of array of ref Fmt): list of array of ref Fmt
{
	r: list of array of ref Fmt;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

# a table's formats, the lines from s to the one ending in .; the line
# after them
tblformats(s: string): (list of array of ref Fmt, string)
{
	fmts: list of array of ref Fmt;
	for(; s != nil; s = readline()){
		t := trim(s);
		last := suffix(".", t);
		if(last)
			t = t[0:len t - 1];
		(nil, rl) := sys->tokenize(t, ",");
		for(; rl != nil; rl = tl rl)
			fmts = tblrow(hd rl) :: fmts;
		if(last)
			break;
	}
	r: list of array of ref Fmt;
	for(; fmts != nil; fmts = tl fmts)
		r = hd fmts :: r;
	return (r, readline());
}

# a format's row: l r c n a s ^ _ = and their fonts (b i f), and rules (|)
tblrow(s: string): array of ref Fmt
{
	cols: list of ref Fmt;
	bars := 0;
	i := 0;
	while(i < len s){
		c := s[i++];
		case c {
		'|' =>
			bars++;
		'l' or 'L' or 'r' or 'R' or 'c' or 'C' or 'n' or 'N' or 'a' or 'A' or
		's' or 'S' or '^' or '_' or '-' or '=' =>
			k := c;
			if(k >= 'A' && k <= 'Z')
				k += 'a' - 'A';
			cols = ref Fmt(k, R, bars, 0) :: cols;
			bars = 0;
		'b' or 'B' =>
			if(cols != nil)
				(hd cols).font = addfont((hd cols).font, B);
		'i' or 'I' =>
			if(cols != nil)
				(hd cols).font = addfont((hd cols).font, I);
		'f' or 'F' =>
			n := "";
			if(i + 2 < len s && s[i] == '('){
				n = s[i + 1:i + 3];
				i += 3;
			}else if(i < len s){
				n = s[i:i + 1];
				i++;
			}
			if(cols != nil)
				(hd cols).font = fontnamed(n);
		'w' or 'W' or 'p' or 'P' or 'v' or 'V' =>
			if(i < len s && s[i] == '('){
				while(i < len s && s[i] != ')')
					i++;
				i++;
			}else
				while(i < len s && (isdigit(s[i]) || s[i] == '.' || s[i] == '+' || s[i] == '-'))
					i++;
		}
	}
	if(cols != nil)
		(hd cols).after = bars;
	n := 0;
	for(l := cols; l != nil; l = tl l)
		n++;
	a := array[n] of ref Fmt;
	for(l = cols; l != nil; l = tl l)
		a[--n] = hd l;
	return a;
}

addfont(f, g: int): int
{
	if(f == B && g == I || f == I && g == B)
		return BI;
	return g;
}

# a data line's cells; a text block (T{ to T}) a cell, marked \001
tblcells(s: string, tab: int): array of string
{
	cells: list of string;
	for(;;){
		c := "";
		i := 0;
		for(; i < len s && s[i] != tab; i++)
			c[len c] = s[i];
		if(c == "T{"){
			blk := "";
			t: string;
			while((t = readline()) != nil && !prefix("T}", t)){
				if(blk != "")
					blk += " ";
				blk += t;
			}
			cells = ("\u0001" + blk) :: cells;
			if(t == nil)
				break;
			s = t[2:];
			if(s != "" && s[0] == tab){
				s = s[1:];
				continue;
			}
			break;
		}
		cells = c :: cells;
		if(i >= len s)
			break;
		s = s[i + 1:];
	}
	a := array[len cells] of string;
	k := len a;
	for(; cells != nil; cells = tl cells)
		a[--k] = hd cells;
	return a;
}

#
# pic's pictures
#

# a picture (pic's, .PS to .PE) or a chess board (chess's, .CB to .CE):
# drawn as a PDF of its own, by its preprocessor, troff and tr2pdf
picture(first, end, cmd: string)
{
	closefont(cur);
	src := first + "\n";
	while((s := readline()) != nil){
		src += s + "\n";
		if(prefix(end, s))
			break;
	}
	npics++;
	stem := "book";
	if(outname != nil){
		stem = outname;
		for(i := len stem - 1; i >= 0; i--)
			if(stem[i] == '.'){
				stem = stem[0:i];
				break;
			}else if(stem[i] == '/')
				break;
	}
	name := stem + "-pic" + string npics;
	emit(cur, "% " + cmd + ":");
	for((nil, l) := sys->tokenize(src, "\n"); l != nil; l = tl l)
		emit(cur, "% " + hd l);
	if(outname != nil && drawpic(src, name, cmd)){
		base := name;
		for(i := len base - 1; i >= 0; i--)
			if(base[i] == '/'){
				base = base[i + 1:];
				break;
			}
		# (set for troff's page, a picture may be wider than a journal's
		# column: it is made narrower, never wider)
		centrein("\\resizebox{\\ifdim\\width>\\linewidth\\linewidth\\else\\width\\fi}{!}{\\includegraphics{" + base + "}}");
	}else
		centrein("\\fbox{\\textit{a picture (" + cmd + ")}}");
	cur.noindent = 1;
}

# a line centred: by the float it is in (\\centering), else by itself
centrein(s: string)
{
	if(infloat != ""){
		emit(cur, s);
		return;
	}
	emit(cur, "\\begin{center}");
	emit(cur, s);
	emit(cur, "\\end{center}");
}

# what troff sets a picture with: -mbook's fonts (small capitals, the
# fallback, the chess figures), as the book has them
figfonts: con ".fp 11 SC R\n.ff SC +smcp\n.fp 12 DF\n.fp 14 CH\n" +
	".char \u2654 \\f[CH]\\N'uni2654'\n.char \u2655 \\f[CH]\\N'uni2655'\n" +
	".char \u2656 \\f[CH]\\N'uni2656'\n.char \u2657 \\f[CH]\\N'uni2657'\n" +
	".char \u2658 \\f[CH]\\N'uni2658'\n.char \u2659 \\f[CH]\\N'uni2659'\n" +
	".char \u265a \\f[CH]\\N'uni265A'\n.char \u265b \\f[CH]\\N'uni265B'\n" +
	".char \u265c \\f[CH]\\N'uni265C'\n.char \u265d \\f[CH]\\N'uni265D'\n" +
	".char \u265e \\f[CH]\\N'uni265E'\n.char \u265f \\f[CH]\\N'uni265F'\n";

# a picture as a PDF of its own: pic's (chess's) .PS line gives its
# height and width; troff sets it on a page that size, with the
# document's characters and fonts, tr2pdf writes it.  Its labels'
# equations are eqn's, with the document's delim and defines
drawpic(src, name, cmd: string): int
{
	sh := load Sh Sh->PATH;
	if(sh == nil){
		warn(sys->sprint("cannot load sh: %r"));
		return 0;
	}
	tmp := name + ".pic";
	pipe := cmd + " < " + quote(tmp);
	if(cmd == "pic" && eqprelude != ""){
		src = eqprelude + src;
		pipe += " | eqn /lib/troff/eqnrc -";
	}
	if(writefile(tmp, src) < 0)
		return 0;
	err := sh->system(ctxt, pipe + " > " + quote(name + ".tr"));
	if(err != nil){
		warn(cmd + ": " + err);
		return 0;
	}
	out := readfile(name + ".tr");
	if(cmd == "pic" && eqprelude != "")
		out = noxspace(out);
	ht := 0.0;
	wd := 0.0;
	for((nil, l) := sys->tokenize(out, "\n"); l != nil; l = tl l)
		if(prefix(".PS ", hd l)){
			(nil, w) := sys->tokenize(hd l, " ");
			if(len w >= 3){
				ht = real hd tl w;
				wd = real hd tl tl w;
			}
			break;
		}
	if(ht <= 0.0 || wd <= 0.0){
		warn(cmd + " gave no size for " + name);
		return 0;
	}
	# pic's size leaves out its labels' text, which may hang past the
	# drawing (a label ljust at its right edge): the picture is set
	# once on a page with room about it, where its ink is found, and
	# again on a page that size
	pw := int (wd * 72.0 + 0.999) + 2;
	ph := int (ht * 72.0 + 0.999) + 2;
	(po, top) := (1, 1);
	pad := 144;
	if(writefile(name + ".tr", picdoc(pw + 2 * pad, ph + 2 * pad, pad, pad, out)) < 0)
		return 0;
	err = sh->system(ctxt, "troff < " + quote(name + ".tr") + " > " + quote(name + ".t1"));
	if(err == nil){
		(ok, x0, y0, x1, y1) := inkbox(readfile(name + ".t1"));
		if(ok){
			m := 2.0;
			pw = int (x1 - x0 + 2.0 * m + 0.999);
			ph = int (y1 - y0 + 2.0 * m + 0.999);
			# (its ink moved from x0, y0 to m, m)
			po = int (m - (x0 - real pad));
			top = int (m - (y0 - real pad));
		}
	}
	sys->remove(name + ".t1");
	if(writefile(name + ".tr", picdoc(pw, ph, po, top, out)) < 0)
		return 0;
	err = sh->system(ctxt, "troff < " + quote(name + ".tr") + " | tr2pdf > " + quote(name + ".pdf"));
	sys->remove(tmp);
	sys->remove(name + ".tr");
	if(err != nil){
		warn("troff | tr2pdf: " + err);
		return 0;
	}
	return 1;
}

# what troff sets a picture by: a page pw by ph points, the picture's
# origin po and top points in, the document's characters and fonts
picdoc(pw, ph, po, top: int, out: string): string
{
	# (a sign would make .po's and .sp's relative: -1p as 0-1p)
	return sys->sprint(".pl %dp\n.po 0%+dp\n.ll %dp\n.vs 0\n\\X'papersize %dx%d'\n.sp |0%+dp\n", ph, po, pw, pw, ph, top) +
		figfonts + trprelude + ".de PS\n..\n.de PE\n..\n" + out;
}

# the box troff's output inks on its first page, in points: its glyphs
# (each from where it is set, by the em of its size: troff's output
# gives a word's last glyph no width) and what it draws
inkbox(s: string): (int, real, real, real, real)
{
	res := 720.0;
	scale := 1.0;
	size := 10.0;
	h := 0.0;
	v := 0.0;
	(x0, y0, x1, y1) := (1e9, 1e9, -1e9, -1e9);
	n := 0;
	i := 0;
	pages := 0;
	while(i < len s){
		c := s[i++];
		case c {
		' ' or '\t' or '\n' or 'w' =>
			;
		'x' =>
			(l, e) := restofline(s, i);
			i = e;
			(nil, w) := sys->tokenize(l, " \t");
			if(w != nil && tl w != nil){
				if(hd w == "res" || hd w == "r")
					res = real hd tl w;
				else if(hd w == "sizescale")
					scale = real hd tl w;
			}
		'#' =>
			(nil, i) = restofline(s, i);
		'p' =>
			(nil, i) = number(s, i);
			if(++pages > 1)
				i = len s;
			h = v = 0.0;
		's' =>
			k: int;
			(k, i) = number(s, i);
			# (devutf's sizes are hundredths of a point, its sizescale
			# not in the output)
			if(scale == 1.0 && k >= 400)
				size = real k / 100.0;
			else
				size = real k / scale;
		'f' =>
			(nil, i) = number(s, i);
		'H' =>
			k: int;
			(k, i) = number(s, i);
			h = real k;
		'V' =>
			k: int;
			(k, i) = number(s, i);
			v = real k;
		'h' =>
			k: int;
			(k, i) = number(s, i);
			h += real k;
		'v' =>
			k: int;
			(k, i) = number(s, i);
			v += real k;
		'n' =>
			(nil, i) = number(s, i);
			(nil, i) = number(s, i);
		'c' or 'C' or 'N' =>
			if(c == 'c')
				i++;
			else if(c == 'C')
				while(i < len s && s[i] != ' ' && s[i] != '\n')
					i++;
			else
				(nil, i) = number(s, i);
			em := size * res / 72.0;
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v - 0.8 * em);
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h + em, v + 0.25 * em);
			n++;
		'D' =>
			(l, e) := restofline(s, i);
			i = e;
			(x0, y0, x1, y1, h, v) = drawn(l, x0, y0, x1, y1, h, v);
			n++;
		* =>
			if(c >= '0' && c <= '9' && i + 1 < len s){	# nnc: a move, then a glyph
				h += real ((c - '0') * 10 + s[i] - '0');
				i += 2;
				em := size * res / 72.0;
				(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v - 0.8 * em);
				(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h + em, v + 0.25 * em);
				n++;
			}else
				(nil, i) = restofline(s, i);
		}
	}
	if(n == 0)
		return (0, 0.0, 0.0, 0.0, 0.0);
	k := 72.0 / res;
	return (1, x0 * k, y0 * k, x1 * k, y1 * k);
}

grow(x0, y0, x1, y1, x, y: real): (real, real, real, real)
{
	if(x < x0)
		x0 = x;
	if(x > x1)
		x1 = x;
	if(y < y0)
		y0 = y;
	if(y > y1)
		y1 = y;
	return (x0, y0, x1, y1);
}

# a drawing (troff's D): the box grown by it, and where it ends
drawn(l: string, x0, y0, x1, y1, h, v: real): (real, real, real, real, real, real)
{
	l = trim(l);
	if(l == "")
		return (x0, y0, x1, y1, h, v);
	cmd := l[0];
	(nil, w) := sys->tokenize(l[1:], " \t");
	a: list of real;
	for(; w != nil; w = tl w)
		a = real hd w :: a;
	na := 0;
	for(t := a; t != nil; t = tl t)
		na++;
	nums := array[na] of real;
	for(; a != nil; a = tl a)
		nums[--na] = hd a;
	case cmd {
	'c' =>	# a circle: its diameter
		if(len nums >= 1){
			d := nums[0];
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v - d / 2.0);
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h + d, v + d / 2.0);
			h += d;
		}
	'e' =>	# an ellipse: its width and height
		if(len nums >= 2){
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v - nums[1] / 2.0);
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h + nums[0], v + nums[1] / 2.0);
			h += nums[0];
		}
	'a' =>	# an arc: to its centre, then to its end; the circle bounds it
		if(len nums >= 4){
			cx := h + nums[0];
			cy := v + nums[1];
			r := hypot(nums[0], nums[1]);
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, cx - r, cy - r);
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, cx + r, cy + r);
			h = cx + nums[2];
			v = cy + nums[3];
		}
	* =>	# lines, splines, polygons: moves from point to point
		(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v);
		for(k := 0; k + 1 < len nums; k += 2){
			h += nums[k];
			v += nums[k + 1];
			(x0, y0, x1, y1) = grow(x0, y0, x1, y1, h, v);
		}
	}
	return (x0, y0, x1, y1, h, v);
}

hypot(x, y: real): real
{
	return math->sqrt(x * x + y * y);
}

# the rest of the line from i, and where the next begins
restofline(s: string, i: int): (string, int)
{
	j := i;
	while(j < len s && s[j] != '\n')
		j++;
	if(j < len s)
		return (s[i:j], j + 1);
	return (s[i:j], j);
}

# a number at i (after spaces), and where it ends
number(s: string, i: int): (int, int)
{
	while(i < len s && (s[i] == ' ' || s[i] == '\t'))
		i++;
	neg := 0;
	if(i < len s && s[i] == '-'){
		neg = 1;
		i++;
	}
	n := 0;
	while(i < len s && s[i] >= '0' && s[i] <= '9')
		n = n * 10 + s[i++] - '0';
	if(neg)
		n = -n;
	return (n, i);
}

# eqn's output without the extra space it asks for a line whose
# equation is taller than the line (\x): a picture is set with .vs 0,
# so every label's would be, and the picture pushed off its page; pic
# places each label itself
noxspace(s: string): string
{
	r := "";
	for((nil, l) := sys->tokenize(s, "\n"); l != nil; l = tl l)
		if(!(prefix(".if ", hd l) && contains(hd l, ".as ") && contains(hd l, "\\x'")))
			r += hd l + "\n";
	return r;
}

quote(s: string): string
{
	r := "'";
	for(i := 0; i < len s; i++){
		if(s[i] == '\'')
			r += "'";
		r[len r] = s[i];
	}
	return r + "'";
}

writefile(name, s: string): int
{
	fd := sys->create(name, Sys->OWRITE, 8r666);
	if(fd == nil){
		warn(sys->sprint("%s: %r", name));
		return -1;
	}
	b := array of byte s;
	if(sys->write(fd, b, len b) != len b){
		warn(sys->sprint("%s: %r", name));
		return -1;
	}
	return 0;
}

readfile(name: string): string
{
	f := bufio->open(name, Bufio->OREAD);
	if(f == nil)
		return "";
	s := "";
	while((t := f.gets('\n')) != nil)
		s += t;
	return s;
}


#
# characters, for pdfLaTeX: those LaTeX's inputenc knows (UTF-8 with
# the fonts T1 and TS1) are kept; a mathematical one is LaTeX's command
# for it, in text or mathematics alike (\ensuremath); any other said
#

# the characters inputenc knows, as pdfLaTeX was found to (first, last)
utfok := array[] of {
	16r00A0, 16r0125, 16r0128, 16r0137, 16r0139, 16r013E, 16r0141, 16r0148,
	16r014A, 16r0165, 16r0168, 16r017E, 16r0192, 16r0192, 16r01C4, 16r01D4,
	16r01E2, 16r01E3, 16r01E6, 16r01EB, 16r01F0, 16r01F0, 16r01F4, 16r01F5,
	16r0218, 16r021B, 16r0232, 16r0233, 16r0237, 16r0237, 16r1E02, 16r1E03,
	16r1E0D, 16r1E0D, 16r1E1E, 16r1E21, 16r1E25, 16r1E25, 16r1E30, 16r1E31,
	16r1E37, 16r1E37, 16r1E43, 16r1E43, 16r1E45, 16r1E45, 16r1E47, 16r1E47,
	16r1E5B, 16r1E5B, 16r1E63, 16r1E63, 16r1E6D, 16r1E6D, 16r1E8E, 16r1E91,
	16r1E9E, 16r1E9E, 16r1EF2, 16r1EF3, 16r200C, 16r200C, 16r2010, 16r2016,
	16r2018, 16r201A, 16r201C, 16r201E, 16r2020, 16r2022, 16r2026, 16r2026,
	16r2030, 16r2031, 16r2039, 16r203B, 16r203D, 16r203D, 16r2044, 16r2044,
	16r204E, 16r204E, 16r2052, 16r2052, 16r20A1, 16r20A1, 16r20A4, 16r20A4,
	16r20A6, 16r20A6, 16r20A9, 16r20A9, 16r20AB, 16r20AC, 16r20B1, 16r20B1,
	16r2103, 16r2103, 16r2116, 16r2117, 16r211E, 16r211E, 16r2120, 16r2120,
	16r2122, 16r2122, 16r2126, 16r2127, 16r212E, 16r212E, 16r2190, 16r2193,
	16r2329, 16r232A, 16r25E6, 16r25E6, 16r25EF, 16r25EF, 16r266A, 16r266A,
	16r27E8, 16r27E9, 16rFB00, 16rFB06
};

texchars(s: string): string
{
	if(!pdftex)
		return s;
	i := 0;
	while(i < len s && s[i] < 16r80)
		i++;
	if(i >= len s)
		return s;
	r := s[0:i];
	for(; i < len s; i++){
		c := s[i];
		if(c < 16r80){
			r[len r] = c;
			continue;
		}
		m := mathsym(c);
		if(m != nil){
			t := textsym(c);
			if(t != nil)
				r += "\\TextOrMath{" + t + "}{" + m + "}";
			else
				r += "\\ensuremath{" + m + "}";
			continue;
		}
		if(knownutf(c)){
			r[len r] = c;
			continue;
		}
		warn(sys->sprint("U+%04X (%c) has no LaTeX for pdfLaTeX: written as [U+%04X]", c, c, c));
		r += sys->sprint("[U+%04X]", c);
	}
	return r;
}

knownutf(c: int): int
{
	for(k := 0; k + 1 < len utfok; k += 2)
		if(c >= utfok[k] && c <= utfok[k + 1])
			return 1;
	return 0;
}

# a character's text, where LaTeX has it in text as well (TS1's)
textsym(c: int): string
{
	case c {
	16r2026 =>	return "\\textellipsis{}";
	16rd7 =>	return "\\texttimes{}";
	16rf7 =>	return "\\textdiv{}";
	16rb1 =>	return "\\textpm{}";
	16rb7 =>	return "\\textperiodcentered{}";
	16rb0 =>	return "\\textdegree{}";
	16rac =>	return "\\textlnot{}";
	16r2020 =>	return "\\textdagger{}";
	16r2021 =>	return "\\textdaggerdbl{}";
	16r2190 =>	return "\\textleftarrow{}";
	16r2191 =>	return "\\textuparrow{}";
	16r2192 =>	return "\\textrightarrow{}";
	16r2193 =>	return "\\textdownarrow{}";
	16r2016 =>	return "\\textbardbl{}";
	16r2212 =>	return "\\textminus{}";
	}
	return nil;
}

# a character's mathematics, LaTeX's (amssymb's)
mathsym(c: int): string
{
	case c {
	16r3b1 =>	return "\\alpha";
	16r3b2 =>	return "\\beta";
	16r3b3 =>	return "\\gamma";
	16r3b4 =>	return "\\delta";
	16r3b5 =>	return "\\varepsilon";
	16r3b6 =>	return "\\zeta";
	16r3b7 =>	return "\\eta";
	16r3b8 =>	return "\\theta";
	16r3b9 =>	return "\\iota";
	16r3ba =>	return "\\kappa";
	16r3bb =>	return "\\lambda";
	16r3bc =>	return "\\mu";
	16r3bd =>	return "\\nu";
	16r3be =>	return "\\xi";
	16r3bf =>	return "o";
	16r3c0 =>	return "\\pi";
	16r3c1 =>	return "\\rho";
	16r3c2 =>	return "\\varsigma";
	16r3c3 =>	return "\\sigma";
	16r3c4 =>	return "\\tau";
	16r3c5 =>	return "\\upsilon";
	16r3c6 =>	return "\\varphi";
	16r3c7 =>	return "\\chi";
	16r3c8 =>	return "\\psi";
	16r3c9 =>	return "\\omega";
	16r3d1 =>	return "\\vartheta";
	16r3d5 =>	return "\\phi";
	16r3d6 =>	return "\\varpi";
	16r3f1 =>	return "\\varrho";
	16r3f5 =>	return "\\epsilon";
	16r393 =>	return "\\Gamma";
	16r394 =>	return "\\Delta";
	16r398 =>	return "\\Theta";
	16r39b =>	return "\\Lambda";
	16r39e =>	return "\\Xi";
	16r3a0 =>	return "\\Pi";
	16r3a3 =>	return "\\Sigma";
	16r3a5 =>	return "\\Upsilon";
	16r3a6 =>	return "\\Phi";
	16r3a8 =>	return "\\Psi";
	16r3a9 =>	return "\\Omega";
	16r391 =>	return "\\mathrm{A}";
	16r392 =>	return "\\mathrm{B}";
	16r395 =>	return "\\mathrm{E}";
	16r396 =>	return "\\mathrm{Z}";
	16r397 =>	return "\\mathrm{H}";
	16r399 =>	return "\\mathrm{I}";
	16r39a =>	return "\\mathrm{K}";
	16r39c =>	return "\\mathrm{M}";
	16r39d =>	return "\\mathrm{N}";
	16r39f =>	return "\\mathrm{O}";
	16r3a1 =>	return "\\mathrm{P}";
	16r3a4 =>	return "\\mathrm{T}";
	16r3a7 =>	return "\\mathrm{X}";
	16r2190 =>	return "\\leftarrow";
	16r2191 =>	return "\\uparrow";
	16r2192 =>	return "\\rightarrow";
	16r2193 =>	return "\\downarrow";
	16r2194 =>	return "\\leftrightarrow";
	16r2195 =>	return "\\updownarrow";
	16r2196 =>	return "\\nwarrow";
	16r2197 =>	return "\\nearrow";
	16r2198 =>	return "\\searrow";
	16r2199 =>	return "\\swarrow";
	16r21a0 =>	return "\\twoheadrightarrow";
	16r21a3 =>	return "\\rightarrowtail";
	16r21a6 =>	return "\\mapsto";
	16r21a9 =>	return "\\hookleftarrow";
	16r21aa =>	return "\\hookrightarrow";
	16r21cc =>	return "\\rightleftharpoons";
	16r21d0 =>	return "\\Leftarrow";
	16r21d1 =>	return "\\Uparrow";
	16r21d2 =>	return "\\Rightarrow";
	16r21d3 =>	return "\\Downarrow";
	16r21d4 =>	return "\\Leftrightarrow";
	16r21dd =>	return "\\leadsto";
	16r27f5 =>	return "\\longleftarrow";
	16r27f6 =>	return "\\longrightarrow";
	16r27f7 =>	return "\\longleftrightarrow";
	16r27f8 =>	return "\\Longleftarrow";
	16r27f9 =>	return "\\Longrightarrow";
	16r27fa =>	return "\\Longleftrightarrow";
	16r27fc =>	return "\\longmapsto";
	16rac =>	return "\\neg";
	16r2200 =>	return "\\forall";
	16r2203 =>	return "\\exists";
	16r2204 =>	return "\\nexists";
	16r2227 =>	return "\\wedge";
	16r2228 =>	return "\\vee";
	16r22a2 =>	return "\\vdash";
	16r22a3 =>	return "\\dashv";
	16r22a4 =>	return "\\top";
	16r22a5 =>	return "\\bot";
	16r22a8 =>	return "\\models";
	16r22a9 =>	return "\\Vdash";
	16r22ac =>	return "\\nvdash";
	16r22ad =>	return "\\nvDash";
	16r25a1 =>	return "\\Box";
	16r25fb =>	return "\\Box";
	16r25c7 =>	return "\\Diamond";
	16r25ca =>	return "\\lozenge";
	16r2234 =>	return "\\therefore";
	16r2235 =>	return "\\because";
	16r2208 =>	return "\\in";
	16r2209 =>	return "\\notin";
	16r220b =>	return "\\ni";
	16r2282 =>	return "\\subset";
	16r2283 =>	return "\\supset";
	16r2286 =>	return "\\subseteq";
	16r2287 =>	return "\\supseteq";
	16r228a =>	return "\\subsetneq";
	16r228b =>	return "\\supsetneq";
	16r2284 =>	return "\\not\\subset";
	16r222a =>	return "\\cup";
	16r2229 =>	return "\\cap";
	16r2205 =>	return "\\emptyset";
	16r2216 =>	return "\\setminus";
	16r2115 =>	return "\\mathbb{N}";
	16r2124 =>	return "\\mathbb{Z}";
	16r211a =>	return "\\mathbb{Q}";
	16r211d =>	return "\\mathbb{R}";
	16r2102 =>	return "\\mathbb{C}";
	16r2119 =>	return "\\mathbb{P}";
	16r22c3 =>	return "\\bigcup";
	16r22c2 =>	return "\\bigcap";
	16r2118 =>	return "\\wp";
	16r2135 =>	return "\\aleph";
	16r228e =>	return "\\uplus";
	16r2293 =>	return "\\sqcap";
	16r2294 =>	return "\\sqcup";
	16r228f =>	return "\\sqsubset";
	16r2291 =>	return "\\sqsubseteq";
	16r2292 =>	return "\\sqsupseteq";
	16r2264 =>	return "\\le";
	16r2265 =>	return "\\ge";
	16r2260 =>	return "\\ne";
	16r2248 =>	return "\\approx";
	16r2261 =>	return "\\equiv";
	16r223c =>	return "\\sim";
	16r2243 =>	return "\\simeq";
	16r2245 =>	return "\\cong";
	16r221d =>	return "\\propto";
	16r226a =>	return "\\ll";
	16r226b =>	return "\\gg";
	16r227a =>	return "\\prec";
	16r227b =>	return "\\succ";
	16r2aaf =>	return "\\preceq";
	16r2ab0 =>	return "\\succeq";
	16r227c =>	return "\\preccurlyeq";
	16r227d =>	return "\\succcurlyeq";
	16r2223 =>	return "\\mid";
	16r2224 =>	return "\\nmid";
	16r2225 =>	return "\\parallel";
	16r2226 =>	return "\\nparallel";
	16r2250 =>	return "\\doteq";
	16r225c =>	return "\\triangleq";
	16r2254 =>	return "\\mathrel{:}=";
	16r22b2 =>	return "\\lhd";
	16r22b3 =>	return "\\rhd";
	16r22b4 =>	return "\\unlhd";
	16r22b5 =>	return "\\unrhd";
	16r22c8 =>	return "\\bowtie";
	16r2266 =>	return "\\leqq";
	16r2267 =>	return "\\geqq";
	16r2272 =>	return "\\lesssim";
	16r2273 =>	return "\\gtrsim";
	16r226e =>	return "\\not<";
	16r226f =>	return "\\not>";
	16r2270 =>	return "\\nleq";
	16r2271 =>	return "\\ngeq";
	16r2262 =>	return "\\not\\equiv";
	16r2249 =>	return "\\not\\approx";
	16r2241 =>	return "\\nsim";
	16rd7 =>	return "\\times";
	16rf7 =>	return "\\div";
	16rb1 =>	return "\\pm";
	16r2213 =>	return "\\mp";
	16rb7 =>	return "\\cdot";
	16r22c5 =>	return "\\cdot";
	16r2219 =>	return "\\bullet";
	16r2218 =>	return "\\circ";
	16r2295 =>	return "\\oplus";
	16r2296 =>	return "\\ominus";
	16r2297 =>	return "\\otimes";
	16r2298 =>	return "\\oslash";
	16r2299 =>	return "\\odot";
	16r2211 =>	return "\\sum";
	16r220f =>	return "\\prod";
	16r2210 =>	return "\\coprod";
	16r222b =>	return "\\int";
	16r222c =>	return "\\iint";
	16r222d =>	return "\\iiint";
	16r222e =>	return "\\oint";
	16r2202 =>	return "\\partial";
	16r2207 =>	return "\\nabla";
	16r221a =>	return "\\surd";
	16r221e =>	return "\\infty";
	16r2032 =>	return "'";
	16r2033 =>	return "''";
	16r2034 =>	return "'''";
	16r2026 =>	return "\\ldots";
	16r22ef =>	return "\\cdots";
	16r22ee =>	return "\\vdots";
	16r22f1 =>	return "\\ddots";
	16r2113 =>	return "\\ell";
	16r210f =>	return "\\hbar";
	16r2217 =>	return "\\ast";
	16r22c6 =>	return "\\star";
	16r2212 =>	return "-";
	16rb0 =>	return "^{\\circ}";
	16r2220 =>	return "\\angle";
	16r2221 =>	return "\\measuredangle";
	16r25b3 =>	return "\\triangle";
	16r25bd =>	return "\\triangledown";
	16r2660 =>	return "\\spadesuit";
	16r2663 =>	return "\\clubsuit";
	16r2661 =>	return "\\heartsuit";
	16r2662 =>	return "\\diamondsuit";
	16r2665 =>	return "\\heartsuit";
	16r2666 =>	return "\\diamondsuit";
	16r22c0 =>	return "\\bigwedge";
	16r22c1 =>	return "\\bigvee";
	16r2a00 =>	return "\\bigodot";
	16r2a01 =>	return "\\bigoplus";
	16r2a02 =>	return "\\bigotimes";
	16r2a04 =>	return "\\biguplus";
	16r2a06 =>	return "\\bigsqcup";
	16r2240 =>	return "\\wr";
	16r2020 =>	return "\\dagger";
	16r2021 =>	return "\\ddagger";
	16r2127 =>	return "\\mho";
	16r2111 =>	return "\\Im";
	16r211c =>	return "\\Re";
	16r2136 =>	return "\\beth";
	16r2016 =>	return "\\|";
	16r230a =>	return "\\lfloor";
	16r230b =>	return "\\rfloor";
	16r2308 =>	return "\\lceil";
	16r2309 =>	return "\\rceil";
	16r27e8 =>	return "\\langle";
	16r27e9 =>	return "\\rangle";
	16r2329 =>	return "\\langle";
	16r232a =>	return "\\rangle";
	16r27e6 =>	return "[\\![";
	16r27e7 =>	return "]\\!]";
	}
	return nil;
}

#
# the preamble: what the book uses
#

preamble(): string
{
	s := "% made by book2tex from " + srcname;
	if(pdftex){
		s += "; for pdfLaTeX:\n";
		if(havecites)
			s += "%\tpdflatex; bibtex; pdflatex; pdflatex\n";
		else
			s += "%\tpdflatex; pdflatex\n";
	}else
		s += "; for LuaLaTeX:\n%\tlualatex; biber; makeindex; lualatex; lualatex\n";
	geom := "\\usepackage[paperwidth=" + papersize[0] + ",paperheight=" + papersize[1] +
		",top=" + margins[0] + ",bottom=" + margins[1];
	case cls {
	"book" =>
		s += "\\documentclass[" + ptsize + ",openright]{book}\n";
		s += geom + ",inner=" + margins[2] + ",outer=" + margins[3] + "]{geometry}\n";
	"article" or "memo" =>
		o := ptsize;
		if(columns == 2)
			o += ",twocolumn";
		s += "\\documentclass[" + o + "]{article}\n";
		s += geom + ",left=" + margins[2] + ",right=" + margins[3];
		if(columns == 2)
			s += ",columnsep=0.2in";
		s += "]{geometry}\n";
	"ieee" =>
		o := clsopts;
		if(o == "")
			o = "journal";
		s += "\\documentclass[" + o + "]{IEEEtran}\n";
	"acm" =>
		o := clsopts;
		if(o == "")
			o = "acmsmall";
		s += "\\documentclass[" + o + "]{acmart}\n";
		s += "% the rights and the venue, as the journal gives them:\n";
		s += "% \\setcopyright{...} \\acmJournal{...} \\acmDOI{...}\n";
	}
	if(pdftex){
		if(cls != "acm"){
			s += "\\usepackage[T1]{fontenc}\n";
			s += "\\usepackage{amsmath,amssymb}\n";
		}
		if(cls == "ieee"){
			s += "\\interdisplaylinepenalty=2500\n";
			if(haveurls)
				s += "\\usepackage{url}\n";
			if(havecites)
				s += "\\usepackage{cite}\n";
		}
	}else{
		s += "\\usepackage{amsmath}\n";
		s += "\\usepackage{fontspec}\n";
		s += "\\usepackage{unicode-math}\n";
		# a character Libertinus lacks (the chess figures) from another
		# font, as troff takes DejaVu Sans's
		s += "\\directlua{luaotfload.add_fallback(\"bookfallback\", {\"Noto Sans Symbols 2:mode=node;\", \"DejaVu Sans:mode=node;\"})}\n";
		s += "\\setmainfont{Libertinus Serif}[RawFeature={fallback=bookfallback}]\n";
		s += "\\setsansfont{Libertinus Sans}[RawFeature={fallback=bookfallback}]\n";
		s += "\\setmonofont{Libertinus Mono}[RawFeature={fallback=bookfallback}]\n";
		s += "\\setmathfont{Libertinus Math}\n";
		s += "\\usepackage{microtype}\n";
		if(cls == "book")
			s += "\\setlength{\\parindent}{1.5em}\n";
	}
	if(haveepigraph){
		s += "\\usepackage{epigraph}\n";
		s += "\\setlength{\\epigraphwidth}{0.6\\textwidth}\n";
		s += "\\setlength{\\epigraphrule}{0pt}\n";
	}
	if(haveendnotes){
		s += "\\usepackage{endnotes}\n";
		if(cls == "book")
			s += "\\counterwithin*{endnote}{chapter}\n";
		s += "\\renewcommand{\\enoteheading}{}\n";
		s += "\\renewcommand{\\notesname}{Notes}\n";
	}
	if(havecites && biblatex()){
		b := bibfile();
		if(!suffix(".bib", b))
			warn(b + " is not BibTeX's, as biblatex needs");
		case style {
		"numeric" =>
			s += "\\usepackage[style=numeric-comp,sorting=none,backend=biber]{biblatex}\n";
		"authordate" =>
			s += "\\usepackage[authordate" + bibopts() + ",backend=biber]{biblatex-chicago}\n";
		* =>
			s += "\\usepackage[notes" + bibopts() + ",backend=biber]{biblatex-chicago}\n";
		}
		if(style != "numeric"){
			# a short note's title the title to its colon, its subtitle
			# left out (CMOS 14.30), as refer's: unless the work has one
			s += "\\DeclareSourcemap{\\maps[datatype=bibtex]{\\map[overwrite=false]{\n";
			s += "  \\step[fieldsource=title, match=\\regexp{\\A(.+?):\\s}, final]\n";
			s += "  \\step[fieldset=shorttitle, origfieldval]\n";
			s += "  \\step[fieldsource=shorttitle, match=\\regexp{\\A(.+?):\\s.*\\Z}, replace=\\regexp{$1}]}}}\n";
		}
		s += "\\addbibresource{" + b + "}\n";
	}
	if(haveindex){
		s += "\\usepackage{imakeidx}\n";
		s += "\\makeindex[intoc,columns=2]\n";
	}
	if(havepics && cls != "acm")
		s += "\\usepackage{graphicx}\n";
	if(havetables && cls != "acm")
		s += "\\usepackage{booktabs}\n";
	if(cls != "ieee" && cls != "acm")
		s += "\\usepackage[hidelinks]{hyperref}\n";
	s += "\\begin{document}\n";
	return s;
}

# refer's style options as biblatex-chicago's (nodoi, nourl)
bibopts(): string
{
	o := "";
	if(hasopt(styleopts, "nodoi"))
		o += ",doi=false";
	if(hasopt(styleopts, "nourl"))
		o += ",url=false";
	return o;
}
