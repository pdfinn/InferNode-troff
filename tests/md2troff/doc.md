---
title: "The k001 *k002* Test"
subtitle: k003 of md2troff
author:
  - name: k004 Writer
    affiliation: k005 Department
    email: k006@example.org
date: k007 November 2026
abstract: |
  The k008 abstract, with *k009* in it.
lang: en-GB
macros: article
columns: 1
bibliography: works.bib
---

# k010 Introduction {#sec:intro}

A paragraph of k011 text with "k012 quoted" words and 'k013 inner'
marks, k014's apostrophe, an en dash -- and an em dash --- and k015...
It has *k016*, **k017**, ***k018***, `k019`, ~~k020~~, H~k021~O and
2^k022^. A [k023 link](https://example.org/k), an address
<https://example.com/k024>, and k025.[^one] A citation follows
k026 [@knuth1984, 17], and a reference to [@sec:method] and
[@tbl:kinds]. Maths $x sup 2$ and k027 costs \$5.
A line k028  
broken k029.

[^one]: The k030 note.

    Its k031 second paragraph.

## k032 Method {#sec:method}

> A k033 quotation's first paragraph,
continued lazily.
>
> Its k034 second paragraph.
>
> > A k035 nested quotation.

1. k036 first item
2. k037 second item, loose:

   its k038 second paragraph.

3. k039 third item, with a list:
   - k040 bullet
   - k041 bullet

7) k042 seventh
8) k043 eighth

- [ ] k044 to do
- [x] k045 done

a. k046 alpha
b. k047 beta

```c
int k048 = 1;	/* a $ and a \ */
.k049 at a line's start
```

    k050 indented code

| k051 Name | k052 Kind | k053 Count |
|:----------|:---------:|-----------:|
| k054      | k055      | 1          |
| k056 with a cell long enough to be set as a block of text | k057 \| pipe | 2 |

Table: The k058 kinds. {#tbl:kinds}

![The k059 figure's caption](fig.png "A small square, grey"){#fig:square width=1in}

***

### k060 Unnumbered {-}

An inline note.^[The k061 inline note.] And k062 [@bringhurst2004].

#### k063 Deeper

$$
y = 1 over 2
$$

```{=troff}
.p
k065 raw troff.
```

<!-- k999 a comment, not set -->

::: notes
k998 speaker notes, not set
:::

::: {.epigraph attrib="k066 Source"}
k067 an epigraph.
:::

[k068 reference link][r] and [r].

[r]: https://example.org/r "Title"
