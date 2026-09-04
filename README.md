# concept.el

> Plain-text conceptual knowledge editor for Emacs

## Introduction

Conceptual knowledge is the often underappreciated third form knowledge which underlies the more commonly studied relational and procedural forms of knowledge. Those more celebrated forms of knowledge answer the questions:

* What is the case?
* How is it done?

However, their specifications seem to come from nowhere. Their underlying genius resides somehow in our heads. Defining effective procedures or coherent relational databases requires firm grounding in domain knowledge. That knowledge is largely conceptual. It doesn't involve calculation, but it captures and organizes patterns in reality which we intuitively map into our own verbal reasoning. It could be thought of as answering the question:

* What does it mean?

In this computer age, conceptual knowledge is still largely captured in free-form documents such as scientific articles or blog tutorials. While modern search tools powered by probabilistic models and artificial intelligence can help us sort through such documents, this package proposes a radically different way of expressing that knowledge: through organizing it in a computer-friendly format from the get-go.

The text format is pretty straightforward. A concept map is a text file with a `.map` extension. Inside of the text file are a series of *ideas*. Every idea has two kinds of components: one which models the abstract conceptual understanding, and the other which captures the concrete actionable details. Every idea starts with a *focus* concept which creates a *relationship block*. Under those can be zero or more *resource blocks*.

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

Take your time to read through that and I think you will find that this sort of knowledge capture is quite fundamental. For domain experts it might seem unnecessary, but for highly multi-disciplinary situations, this can be a life saver for many people working together on a large project. The best plan can only emerge once you have a comprehensive view of the possibilities. A concept map is meant to be quite comprehensive, at least within a specific domain.

The text format used by `concept.el` is designed to be familiar and comfortable to people with experience writing a little bit of lisp code. Note that concepts, resources, relationships, and attribute keywords are intended to be assigned identifiers which look a lot like lisp symbols. This should be familiar to most people using Emacs as their editor. Once you accept this restriction on naming, you buy into a set of constraints which facilitate the creation of a bunch of very useful editing tools for making huge concept maps quickly.

These editing tools include:

* a variety of (full and partial) text-completion interfaces
* parser validation implemented via a `peg` parsing expression grammar
* hyper-linking to external documents, image files, as well as online documentation
* whole file scanning provided through `imenu`
* document navigation and re-organization system provided through `outline` just like `org` mode
* a search interface and query language provided through `consult`

Together they make it feasible to develop and productively explore concept maps with hundreds of thousands of concepts and even more relationships between them.

## Installation

Install via ELPA (eventually!). Run M-x `package-install`. Press `ENTER`. Type `concept`. Press `ENTER`.

## Thinking about concepts

When you think about a particular thing, you use the singular voice: you speak of the cat and the mouse. When you think about things in general you use the plural voice, you speak of cats and mice. When you follow this convention of naming concepts with plural words, you realize that concepts have three distinct pieces:

* a classification or categorization piece
* a core concept piece
* a definition piece

For example, concept the concept:

> abstract-pieces-of-knowledge

This concept can be broken down into:

```
class: abstract
core: pieces
definition: of-knowledge
```

Gaining an intuition for what this concept is about requires first understanding what is meant by knowledge, pieces, and abstraction. These are often best sharpened by finding their opposites or complements. The opposite of abstract is concrete or definite. The opposite of piece is part of something, which might contain many smaller pieces at a different level. Knowledge concerns successful prediction. Ignorance means almost suredly unsuccessful prediction.

In `concept.el` we encourage you to put the classification piece on the left, the core piece in the middle, and the definition piece on the right. Further, it's better to start with the core plus some definition. Then, once you have your definition, you can added a category which alludes to that definition via and `:name` relationship.

```
~ beings
| :include
| beings-that-die
| beings-that-never-die
~ mortal-beings
| :name
| beings-that-die
~ immortal-beings
| :name
| beings-that-never-die
~ beings
| :include
| immortal-beings
| mortal-beings
```

Redundancy isn't too much of a problem since the main thing is that you understand what you are talking about and that you can gain that understanding by searching through a concept map. 

The package provides an implementation of the longest common substring algorithm to help build tools for automatically identifying these components. This can be combined with the string-distance procedure and tools which provide you a list of all concepts in the buffer to find likely core concepts. Of course, really discovering this will often require a degree of standardization which is not really possible with Emacs, but should be feasible from a dedicated data analysis environment like R.

## Navigating through concept maps

Concept maps inherit from `outline-minor-mode`. This gives a whole suite of keyboard shortcuts and M-x commands which automatically work with concept maps. Navigating up and down is implemented with `M-n` and `M-p`. Otherwise, you can press `C-c C-n` or `C-c C-p` for a more advanced contextual method of navigating through concept maps. This can be useful for finding ideas or resources with certain interesting features. For example, you might want to find ideas with conceptual *relationship blocks* having two relationships instead of one. To do that, place your cursor on the nearest subject line. Then press `C-c C-n`. You will be prompted for the number of objects you want there to be since there is one relationship for each subject-verb-object triple.

If you want to look for ideas with a certain number of relationship groups, press `C-c C-n` from a relationship group line. Similarly, if you want to go forward to the next resource group with a desired number of data lines, place the cursor on a resource line.

Leveraging the tools in `consult.el` can be another very effective way of exploring a concept map. So can `C-s` and `C-r`. Later we will discuss some more powerful block-aware search tools that can be very convenient when the line oriented search tools just don't cut it.

## Editing tools for concept maps

`concept.el` provides a wealth of tools for rapidly entering new ideas and editing existing concept maps to standardize their contents in order to make them as useful a learning tool as possible. Let's start by create a new concept. 

Open the `example.map` concept map included in the git repository. Navigate to the beginning of the buffer with `M-<`. Then press `C-o`. This makes a new idea block by creating a new subject line. Type out `stuff`. Then, press `M-i`. This inserts an `:include` relationship and creates an object concept line. Press `M-i` again and it will enter `stuff` again automatically. `M-.` will do the same, while `C-M-.` will add the following subject instead.

The difference between `M-i` and `M-.` is that `M-.` and `C-M-.` will always enter these concepts, while `M-n` does different things depending on where on the line or where in the idea you are. It tries to help you do what you mean, while `M-.` tries to be specific. Enter `cool-stuff` by moving the cursor to the beginning of the concept. This can be done with `C-M-b` which is a built-in editor shortcut for `backward-sexp`. Otherwise you could just type `M-b` repeatedly until you get there. Now type out `cool-`. From hear you can type `M-i` and it will make a new line for you. Now type out `hot-` followed by `M-.` to write `hot-stuff`. Now press `M-o` to make a new subject line filled in automatically with `hot-stuff`. Press `M-i` again and type out `very-` followed by `M-.` to write `very-hot-stuff`.

Now type `M-o` again to make a new subject line automatically filled out with `very-hot-stuff`. Now press `M-i`. Now press `M-1 M-.` to enter `stuff`. Now complete it with `-that-has-many-layers`. Therefore, you have typed out `stuff-that-has-many-layers`. Now press `M-i` followed by `C-.`. `C-.` inserts the last object line instead of the last subject line. As you might imagine, `C-1 C-.` inserts the last word of the last object, just as `M-1 M-.` inserts the last word of the last subject. Note that if you had instead asked for `M--1 M-.` you would have gotten the first word of the last subject. Similarly, `C--1 C-.` would give you the first word of the next subject.

Now press `C-s many` followed by `M-DEL` to kill the word `many`. Replace it with few. Now press `M-i` again. Toggle it into a subject concept by cycling the first character with `M-r` until it is a `~`. Now press `M-.` to insert the previous subject. When you are new to concept maps, all these different keybindings may be confusing and a bit hard to remember. So, `concept.el` provides a simpler alternative. Navigate to the beginning of the line with `C-M-b` and kill the rest of the line with `C-k`. Now press `TAB` and filter down to the last concept just by typing under the completing-read selection is the concept you want.

Note that just like with resources, you could also auto-complete against all *relationship blocks*. Just press `C-c y c` on a new line between existing ideas.

## Making abstract ideas concrete with resource blocks

You can enter *resource blocks* by typing @ on a new line (e.g. created with `C-j`  or by `M-j` (or even `M-i` in many cases) followed by `M-r` to cycle until a `@` appears. Alternatively, if you want to start from an existing resource, you can press `C-c y r` to auto-complete across all existing resource entries. Once you have a resource block, you can navigate through and edit them with `M-i` which does useful things for whatever situation the cursor is in. When you want to edit the parent keyword for your attribute group, you can press `C-c e` on your attribute line and the cursor will move back to your keyword and delete it. If that is not what you want, then you can undo with `C-x u`. In that case, after the undo you might just want to press `TAB` to see what the other keywords are in your concept map and select one of those.

It can be very convenient to use (e.g. tempel or tempo) templates to insert *resource blocks*. In my `init.el` configuration file I have bound the following tempel configuration for concept maps.

```
(defun tempel-setup-capf ()
  (setq-local completion-at-point-functions
              (cons #'tempel-expand completion-at-point-functions))
  (add-hook 'conf-mode-hook 'tempel-setup-capf)
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf))

(with-eval-after-load 'tempel
  (define-key concept-mode-map (kbd "C-c t") #'tempel-expand)
  (define-key concept-mode-map (kbd "C-c n") #'tempel-next)
  (define-key concept-mode-map (kbd "C-c C-c") #'tempel-done)
  (define-key concept-mode-map (kbd "C-c p") #'tempel-previous))

(require 'tempel)
```

You can use `M-i` to make new attribute group keywords. However, by default these show up as `note:`. You'll have to edit these using standard text editing commands. Type `C-r note:`. Press `ENTER`. Now press `M-d` to delete the word. You could also run M-x `concept-goto-last-attribute` followed by `C-M-b` and then M-x `zap-up-to-char` and enter `:`. Then press `ENTER`. Reorganizing existing attribute groups, or expository data lines can be done with `M-<up>` (up arrow key) and `M-<down>` (down arrow key). The same commands also work with conceptual *relationship blocks*.

Once you have your *resource block* written the way you like it, Pressing `C-c f` can be used on exposition lines inside of the following attribute groups out of the box.

* `file:` to open other files
* `url:` to open webpages in an `EWW` buffer
* `info:` to open info documentation
* `man:` to open manpages

Note that if the file path given under a `file:` keyword cannot be intelligibly opened from within Emacs, `concept.el` will try to open it with M-x `mailcap-view-data`. This will consult your `mailcap` file if it exists, otherwise it will look at the Emacs variable `mailcap-user-mime-data`. Below is an example which tells Emacs how to open a video file with the `mpv` shell command.

```
(setopt mailcap-user-mime-data
        (list (list "mpv -- %s" "video/.*")))
```

There are a few situations where indirectly followed files make sense. One of them involves the combination of a PDF file and a page number. So, when inside a resource block with a `page:` keyword and a `file:` keyword, and the attribute under that `file:` keyword is a PDF file, then pressing `C-c f` on the attribute under the `page:` keyword will open the PDF file, and then navigate to the given PDF page. Similarly, a variety of other plain-text files take `search-phrase:` queries which open those files, go to the beginning of the buffer, and then search forward to the first match of the search phrase.

There is also integration with the Emacs online tools including the help system. The following keywords help document Emacs-specific topics.

* `emacs-symbol:` to run M-x `describe-symbol`
* `emacs-package:` to run M-x `describe-package`
* `emacs-keybinding:` (or `kbd:`) to run M-x `describe-key`

In addition, attribute data under the following keywords can be followed leveraging common Emacs facilities:

* `emacs-buffer:` to run `switch-to-buffer`
* `emacs-command` (or `M-x:`) to run `call-interactively` on the intern'd data
* `emacs-lisp` (or `elisp`) to run arbitrary Emacs Lisp expressions

Of course, running emacs commands and lisp code can be dangerous. Use responsibly! Emacs Lisp expressions output their results into a dedicated buffer which can be readily changed into a subset of Markdown called Gemtext. So, you can easily change this to buffer from special mode into Markdown or Gemtext, whichever you prefer!

## Searching through concept maps

There is one hard dependency not provided out of the box with Emacs: the `consult.el` package on ELPA. Many of the commands in `consult.el` are useful in their own right for exploring concept maps: `consult-line` in particular, but that can only search across individual lines. In `concept.el`, the underlying functionality of `consult.el` is used to implement a convenient interface for searching through conceptual relationships and supporting resources at the block level. `C-c s` starts searches across conceptual *relationship blocks*, while `C-c C-s` starts searches through *resource blocks*.

Both search interfaces feature a query language based around triples. Conceptual *relationship blocks* have an additional simpler query language which makes finding ideas that involve certain combinations of phrases anywhere inside of them easy. Take for example the query below which matches 3 ideas from the concept map example shown above in this document. Note that the `@` signals `DO NOT MATCH`.

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

This matches the ideas about `relationship-blocks` and `resource-blocks`. The related query below should give the same matches as this one. The only difference is that it allows the subject to be anything.

```
~hold~group
```

We can further allow the relationship block to be anything, and on this simple concept map we get the same answer.

```
~~group
```

The *resource block* queries work just the same as these relationship triple queries. The query below finds all the `understanding` resources with `note:` keywords:

```
und~no
```

It could be tightened by leveraging anchors. `^` means that the name starts with `u`.

```
^und~^no
```

It could also be tightened by adding more clauses to the query. This is done via adding a `:` clause separator. You can use as many clauses as you need.

```
und~no:~from$
```

This one only matches the one idea with a `derived-from:` keyword. The `$` means that the name ends with `m`.

## Checking the concept map syntax

Execute `C-c C-v` to check whether your concept map conforms to the expected concept map syntax. If it doesn't, it will move the cursor to the first violation. Once you are familiar with the syntax of concept maps, it is usually obvious what the problem is and you can fix it. Once it's fixed, you can press `C-c C-v`, make your new fixes, and repeat until finally the command places a message in the minibuffer that the syntax now parses.

Once the concept map parses successfully, searching should be guaranteed to work as intended and you should be able to run M-x `concept-map-export-to-table` or press `C-c C-t` to construct a tab-separated table which you can save to disk and then load into another tool like the `conceptuel` package in R. You can also take the generated preliminary exported table buffer `*concept-map-export*` and run M-x `concept-table-export-to-gexp` which will produce a `*relationship-export-gexf*` buffer which can be saved as a GEXF (XML) file and then loaded into the Gephi interactive network analysis program. However, note that currently only the concept map part of the network survives in this step. None of the resource block data is saved in the GEXF file as of yet. Further note that creating the GEXF export can be rather time consuming for large concept maps. Expect it to take a minute or two.

## Future Plans and Related Projects

There are still some bugs to clear up with the query language. In particular, it would be nice to allow general regular expression searches. However, at the moment this is impossible since regular expressions are already used to implement the existing search tools. Regular expressions that match regular expressions are a bit too tricky for the current implementation to handle. However, note that `^` and `$` anchors are allowed. A more sophisticated method would be required. Whatever the implementation and feature set of the search functionality, It would be nice to have an exhaustive test suite implemented which checks that basic searches work as intended.

The current query system is well tailored towards providing an overview of all the ideas related to a given concept or resource. This assumes that the concept map is largely complete and well-standardized. Our experience is that this is seldom the case. We want to make a parallel query interface which is otherwise identical except that it only finds the next match for a query. Perhaps it could be triggered with a C-u on the original commands? This functionality would be extremely useful for constructing keyboard macros to clean up and standardize concept maps.

In the future it would be nice if this dependency on `consult.el` could be made optional. The problem is that I just don't see how to effectively explore a large concept map without it's interactive preview features.

A companion package very useful for editing concept maps in `concept.el` is the `tempel` snippet template editor. However, it's emphasis on determining the available templates based on only the major-mode is too cumbersome for the needs of writing concept maps. A concept map about math benefits from templates around a specific math textbook, but a concept map about architectural design techniques does not! In the future, I want to propose a patch to that tool which enables it to automatically recognize project-specific templates.

One way a programmer might think of a concept map (as imagined in `concept.el`) is as a language grammar. Or. The package could use some tools which probe the implicit conceptual relationships and help make them into explicit conceptual relationships. However, such a feature might be better served by `conceptuel`, an R package which takes as input the tabular output generated by `concept-map-export-to-table`.

Concept maps should be meaningful to many people, not just their creators. To make that a reality, `concept.el` should gain features which make it easier to merge two concept maps together. One possible way this could be done is through achieving a canonical ordering of ideas based on their subjects and possibly their length. Some code to this effect has already been included, but it is not completely functional. However, it's shaping up to look like there will be interactive commands for sorting, reversing, and randomizing the order of all meaningful elements inside of concept maps. When it comes to sorting, currently we are aiming for alphabetic sorting to start. However, it seems like a good idea to aim for a fully custom sorting method as well so that what is canonical can be chosen by what makes sense to the research group. For example, alphabetic sorting doesn't make much sense for attribute group keywords. I have noticed that I frequently create FAQ style resource blocks and I am not particularly interested in reading ones like:

```
@ understanding
| answer:
| {4}
| question:
| {What is 2+2?}
```

Thinking about names in a standard way would really help with merging two different concept maps as well. So, in the future we hope to provide tools for parsing concepts in terms of the `{classification|core|definition}` framework discussed earlier. One challenge we have frequently seen is that concept names start getting longer and longer the more we work with concept maps. Tasteful categorization can help, but, e.g., when dealing with documenting useful elisp functions, it become useful to make some shorthand summarizations for brevity. These can challenge the power of these tools, but there may be useful conventions which can overcome these issues.
