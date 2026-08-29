# concept.el

> Plain-text conceptual knowledge editor for Emacs

## Introduction

Conceptual knowledge is the often underappreciated third form knowledge which underlies the more commonly studied procedural and relational forms of knowledge. Those more celebrated forms of knowledge answer the questions:

* What is the case?
* How is it done?

However, their specifications seem to come from nowhere. Their underlying genius resides somehow in our heads. Defining effective procedures or coherent relational databases requires firm grounding in domain knowledge. That knowledge is largely conceptual. It doesn't involve calculation, but it captures and organizes patterns in reality which we intuitively map into our own verbal reasoning. It could be thought of as answering the question:

* What does it mean?

In this computer age, conceptual knowledge is still largely captured in free-form documents such as scientific articles or blog tutorials. While modern search tools powered by probabilistic models and artificial intelligence can help us sort through such documents, this package proposes a radically different way of expressing that knowledge: through organizing it in a computer-friendly format from the get-go.

The text format is pretty straightforward. A concept map is a text file with a `.map` extension. Inside of the text file are a series of *ideas*. Every idea has two kinds of components: one which models the abstract conceptual understanding, and the other which captures the concrete actionable details. Every idea starts with a *focus* concept which creates a *relationship block*.

```
~ things
| :include
| concepts
| relationships
~ things
| :include
| single-things
| multiple-things
@ understanding
| note:
| {Understanding is based on contrast.}
| idea:
| {SMT}
~ concepts
| :include
| single-concepts
| multiple-concepts
@ understanding
| note:
| {Concepts are things.}
| {Thus, these relationships are implied by SMT.}
| derived-from:
| {SMT}
~ relationships
| :include
| single-relationships
| multiple-relationships
~ concepts
| :include
| subjects
| objects
@ understanding
| note:
| {All ideas have one and only one subject.}
| {The subject is given first and indicated with a tilde: ~.}
@ understanding
| note:
| {In english grammar, a simple sentence has a subject, a verb, and an object.}
| {Here ideas correspond roughly to multiple related simple sentences.}
~ ideas
| :hold
| relationship-blocks
| resource-blocks
~ relationship-blocks
| :hold
| relationship-groups
~ relationships
| :include
| relationships-between-mental-objects
| relationships-between-physical-objects
~ relationships-between-mental-objects
| :include
| relationships-between-concepts
~ relationship-blocks
| :capture
| relationships-between-concepts
~ relationship-groups
| :hold
| multiple-objects
| :share
| single-relationships
@ understanding
| note:
| {Keywords beginning in colons signify the start of a new relationship group.}
~ resource-blocks
| :hold
| attribute-groups
@ understanding
| note:
| {Keywords ending in colons signify the start of a new attribute group.}
~ pieces
| :include
| pieces-of-knowledge
| pieces-of-intuition
~ pieces-of-knowledge
| :include
| abstract-pieces-of-knolwedge
| concrete-pieces-of-knolwedge
@ understanding
| note:
| {It's hard to comprehend abstract ideas without considering the many concrete examples which hint at them.}
~ concrete-pieces-of-knolwedge
| :include
| relevant-concrete-pieces-of-knolwedge
| irrelevant-concrete-pieces-of-knolwedge
~ attribute-groups
| :capture
| concrete-pieces-of-knolwedge
~ concrete-pieces-of-knowledge
| :include
| facts
| references
| thoughts
```

Take your time to read through that and I think you will find that this sort of knowledge capture is quite fundamental. For domain experts it might seem unnecessary, but for highly multi-disciplinary situations, this can be a life saver for many people working together on a large project. The best plan can only emerge once you have a comprehensive view of the possibilities. A concept map is meant to be quite comprehensive, atleast within a specific domain.

The text format used by `concept.el` is designed to be familiar and comfortable to people with experience writing a little bit of lisp code. Note that concepts, resources, relationships, and attribute keywords are intended to be assigned identifiers which look a lot like lisp symbols. This should be familiar to most people using Emacs as their editor. Once you accept this restriction on naming, you buy into a set of constraints which facilitate the creation of a bunch of very useful editing tools for making concept maps quickly.

These editing tools include:

* a variety of text-completion interfaces
* parser validation implemented via a `peg` parsing expression grammar
* hyper-linking to external documents
* whole file scanning provided through `imenu`
* document navigation and re-organization system provided through `outline` just like `org` mode
* a search interface and query language provided through `consult`

## Installation

Install via ELPA (eventually!).

## Editing tools for concept maps

There is ubiquitous `TAB` completion. Before we can show it, though we need to create a new concept. Navigate to the beginning of the buffer with `M-<`. Then press `C-o`. This makes a new idea block by creating a new subject line. Type out `stuff`. Then, press `M-i`. This inserts an `:include` relationship and creates an object concept line. Press `M-i` again and it will enter `stuff` again automatically. `M-.` will do the same, while `C-M-.` will add the following subject instead. The difference between `M-i` and `M-.` is that `M-.` and `C-M-.` will always enter these concepts, while `M-n` does different things depending on where on the line or where in the idea you are. It tries to help you do what you mean, while `M-.` tries to be specific. Enter `cool-stuff` by moving the cursor to the beginning of the concept. This can be done with `C-M-b` which is a built-in editor shortcut for `backward-sexp`. Otherwise you could just type `M-b` repeatedly until you get there. Now type out `cool-`. From hear you can type `M-i` and it will make a new line for you. Now type out `hot-` followed by `M-.` to write `hot-stuff`. Now press `M-o` to make a new subject line filled in automatically with `hot-stuff`. Press `M-i` again and type out `very-` followed by `M-.` to write `very-hot-stuff`.

Now type `M-o` again to make a new subject line automatically filled out with `very-hot-stuff`. Now press `M-i`. Now press `M-1 M-.` to enter `stuff`. Now complete it with `-that-has-many-layers`. Therefore, you have typed out `stuff-that-has-many-layers`. Now press `M-i` followed by `C-.`. `C-.` inserts the last object line instead of the last subject line. Now press `C-s many` followed by `M-DEL` to kill the word `many`. Replace it with few. Now press `M-i` again. Toggle it into a subject concept by cycling the first character with `M-r` until it is a `~`. Now press `C-M-.` to insert the previous subject. Well, that way is confusing and a bit hard to remember. Navigate to the beginning of the line with `C-M-b` and kill the rest of the line with `C-k`. Now press `TAB` and filter down to the last concept just by typing under the completing-read selection is the concept you want.

## Searching through concept maps

There is one hard dependency not provided out of the box with Emacs: the `consult.el` package on ELPA. Many of the commands in `consult.el` are useful in their own right for exploring concept maps: `consult-line` in particular, but that can only search across individual lines. In `concept.el`, the underlying functionality of `consult.el` is used to implement a convenient interface for searching through conceptual relationships and supporting resources at the block level. `C-c s` starts searches across conceptual relationship blocks, while `C-c C-s` starts searches through resource blocks.

Both search interfaces feature a query language based around triples. Conceptual relationship blocks have an additional simpler query language which makes finding ideas that involve certain combinations of phrases anywhere inside of them easy. Take for example the query below which matches 3 ideas from the concept map example shown above in this document. Note that the `@` signals `DO NOT MATCH`.

```
concept;relationship;@group
```

The subjects for those matches are:

```
~ things
~ relationships-between-mental-objects
~ relationship-blocks
```

An example of a relationship search would be:

```
~@include
```

This matches the 6 ideas that don't have `:include` relationships. Note the single `~`. This means that the subject and object concepts can be anything. Again, the `@` means `DO NOT MATCH`. Here is a more involved example query.

```
block~hold~group
```

This matches the ideas about `relationship-blocks` and `resource-blocks`. The related query below should give the same matches as this one. It just allows the subject to be anything.

```
~hold~group
```

The resource block queries work just the same as these relationship triple queries. The query below finds all the `understanding` resources with `note:` keywords:

```
und~no
```

It could be tighted by leveraging anchors. `^` means that the name starts with `u`.

```
^und~^no
```

It could also be tightened by adding more clauses to the query.

```
und~no:~from$
```

This one only matches the one idea with a `derived-from:` keyword. The `$` means that the name ends with `m`.

## Checking the concept map syntax

Execute `C-c C-v` to check whether your concept map conforms to the expected concept map syntax. If it doesn't, it will move the cursor to the first violation.

## Future Plans and Related Projects

There are still some bugs to clear up with the query language. It would be nice to have a test suite implemented which checks that basic searches work as intended.

In the future it would be nice if this dependency on `consult.el` could be made optional. The problem is that I just don't see how to effectively explore a large concept map without it's interactive preview features.

A companion package very useful for editing concept maps in `concept.el` is the `tempel` snippet template editor. In the future, I want to propose a patch to that tool which enables it to automatically recognize project-specific templates.

One way a programmer might think of a concept map (as imagined in `concept.el`) is as a language grammar. Or. The package could use some tools which probe the implicit conceptual relationships and help make them into explicit conceptual relationships. However, such a feature might be better served by `conceptuel`, an R package which takes as input the tabular output generated by `concept-map-export-to-table`.

Concept maps should be meaningful to many people, not just their creators. To make that a reality, `concept.el` should gain features which make it easier to merge two concept maps together. One possible way this could be done is through achieving a canonical sorting of ideas based on their subjects and possibly their length. Some code to this effect has already been included, but it is not completely functional.
