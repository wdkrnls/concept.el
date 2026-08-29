# concept.el

> Plain-text conceptual knowledge editor for Emacs

## Introduction

Conceptual knowledge is the often underappreciated third form knowledge which underlies the more commonly studied procedural and relational forms of knowledge. Those more celebrated forms of knowledge answer the questions:

* "What is?"
* "How to?"

However, their specification seem to come from nowhere. Their underlying genius resides somehow in our heads. Defining effective procedures or coherent relational databases requires firm grounding in domain knowledge. That knowledge is largely conceptual. It doesn't involve calculation, but it captures and organizes patterns in reality which we intuitively map into our own verbal reasoning. 

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

## Future Plans and Related Projects

A companion package very useful for editing concept maps in `concept.el` is the `tempel` template editor. In the future, I want to propose a patch to that tool which enables it to automatically recognize project-specific templates.

One way a programmer might think of a concept map (as imagined in concept.el) is as a language grammar. Or. The package could use some tools which probe the implicit conceptual relationships and help make them into explicit conceptual relationships. However, such a feature might be better served by `conceptuel`, an R package which takes as input the tabular output generated by `concept-map-export-to-table`.
