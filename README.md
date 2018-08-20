# Pludeck

[![Quicklisp](http://quickdocs.org/badge/pludeck.svg)](http://quickdocs.org/pludeck/)

Pludeck is a small Common Lisp library offering a friendly interface for
creating a [Plump][plump] DOM.

It depends only on [Plump][plump] (Artistic License 2.0)

[plump]: https://shinmera.github.io/plump/

## Installation

Once Pludeck is in a Quicklisp dist, it can be loaded without any further
action:

```lisp
(ql:quickload :pludeck)
```

If not, you can clone this repository into `quicklisp/local-projects`. You may
need to call `(ql:register-local-projects)`, after which you can use the same
form as above.

## Usage

```lisp
;;; This example generates a document in an imaginary format.

(<>root
  (<?xml "version" "1.0")
  (<!-- "This is a Pludeck example")
  (<> ("document" "markupSyntax" "imaginary" :encoding "utf-8")
    (<> "title" "Fixnums are cool")
    (<> "blocks"
      (<> "paragraph"
        "The maximum value of a fixnum on this system is "
        most-positive-fixnum
        ". That's a lot!")
      (<> ("image" :src "https://example.com/woah.png")))))
```

Pludeck exports a number of macros, all of which have names starting with `<`.
Some represent specific XML elements you could find in an XML document, in
which case the name is made to look like the opening of such an element. This
includes `<?xml` and `<!--`, used above. Other macros are more general or
abstract, in which case the name starts with `<>`. This includes `<>root` and
the general element construction macro `<>`.

To insert a text node into the DOM, the macro `<>text` can be used. It calls
`PRINC-TO-STRING` on its argument. You may notice the above example does not
include any invocations of `<>text`, which is because Pludeck will
automatically wrap it around certain expressions in the body of an element. The
rule for this is very simple: If it's not a literal list, it gets wrapped in
`<>text`. This replacement does not recurse into the tree. This rule allows you
to insert literal values and variables directly into the tree, without
explicitly marking them as text.

Pludeck also offers a way to define specific macros for the XML elements you
want to use. These can help clean up your code if you use the same elements
often.

```lisp
;;; This is the same example, but with a macro for each type of element.

(<>define <document "document" :attributes t :content t)
(<>define <title> "title" :content t)
(<>define <blocks> "blocks" :content t)
(<>define <paragraph> "paragraph" :content t)
(<>define <image "image" :attributes t)

(<>root
  (<?xml "version" "1.0")
  (<!-- "This is a Pludeck example")
  (<document ("markupSyntax" "imaginary" :encoding "utf-8")
    (<title> "Fixnums are cool")
    (<blocks>
      (<paragraph>
        "The maximum value of a fixnum on this system is "
        most-positive-fixnum
        ". That's a lot!")
      (<image :src "https://example.com/woah.png"))))
```

## Syntax rationale

The Common Lisp ecosystem has various different solutions for turning
S-expressions into HTML. Most notable is probably the [CL-WHO][cl-who] family,
but there is also [YACLML][yaclml] ([syntax description][yaclml-syntax]).

The CL-WHO syntax requires a tradeoff between being aggressive by assuming
anything in the body that *looks* like `(:tag)` is meant to be a tag (which
[Spinneret][spinneret] does), and requiring any tags nested inside other code
to be explicitly wrapped in some form (which [CL-WHO][cl-who] does with its
`HTM`). Both of these require some level of code walking.

The fact that XML is case-sensitive, unlike HTML, means a CL-WHO-like approach
would need to either support `("Tags" :like "this")`, or require users to use
escaped symbols, `(:|Tags| :like "this")`. This makes the aggressive approach
more overbearing than it already is, and can turn even the conservative
approach into a bit of a mess.

The [YACLML][yaclml] solution is a bit nicer, since each tag is simply a macro.
It uses a package named `<` to give tags a distinct look, which also helps make
things clearer. Pludeck looks more like YACLML than like CL-WHO, though it
doesn't include a package pre-filled with HTML tags. Instead it uses symbol
names starting with `<`.

[cl-who]: https://edicl.github.io/cl-who/
[yaclml]: https://github.com/sharplispers/yaclml
[yaclml-syntax]: https://trac.common-lisp.net/ucw/wiki/IntroYaclmlTags
[spinneret]: https://github.com/ruricolist/spinneret

## Reference

### `<>root`

At the top of a DOM tree you need a DOM root:

```lisp
(defmacro <>root (&body body)
  "Bind a new Plump DOM root as the parent for enclosed elements.

Note that this binding is dynamic, meaning an element constructed inside a
function called from the body will also have this DOM root as its parent.

Any non-list in the body (non-recursive) is wrapped in a call to <>TEXT.

Returns the constructed DOM root."
  ...)
```

### `<>wrap`

You can use any DOM element as a parent:

```lisp
(defmacro <>wrap (parent &body body)
  "Bind the given element as the parent for enclosed elements.

Note that this binding is dynamic, meaning an element constructed inside a
function called from the body will also have this DOM root as its parent.

Any non-list in the body (non-recursive) is wrapped in a call to <>TEXT.

Returns the given parent element."
  ...)
```

### `<>`

Constructing arbitrary DOM elements is easy with `<>`:

```lisp
(defmacro <> (tag/attributes &body body)
  "Create a new element, with the closest enclosing element as the parent. This
element will in turn serve as the parent for any elements constructed in its
body.

Note that this binding is dynamic, meaning an element constructed inside a
function called from the body will also have this DOM root as its parent.

TAG/ATTRIBUTES can either be a string, which will be used as the tag name, or a
list. If it is a list, the first item should be a string that serves as the tag
name, and the rest of the items form a plist of attribute names and values.
Both the names and the values are evaluated. If a name evaluates to a symbol,
its lowercased name is used as the attribute name. In all other cases the value
of (PRINC-TO-STRING name) is used. The values are also passed to
PRINC-TO-STRING.

Any non-list in the body (non-recursive) is wrapped in a call to <>TEXT.

Returns the constructed element."
  ...)
```

### `<>text`

Text nodes can be constructed using `<>text`, though this call can often be
implicit:

```lisp
(defmacro <>text (content)
  "Create a new text node with the closest enclosing element as the parent.
CONTENT is passed to PRINC-TO-STRING.

Returns the constructed text node."
  ...)
```

### `<>fulltext`

Plump also has the construct of a fulltext node, used for `<style>` and
`<script>` in HTML.

```lisp
(defmacro <>fulltext (tag/attributes content)
  "Create a new fulltext node with the closest enclosing element as the parent.
CONTENT is passed to PRINC-TO-STRING.

A fulltext node is a DOM element that contains text that is not escaped using
HTML entities. This is primarily useful for <style> and <script> in HTML.

Returns the constructed text node."
  ...)
```

### `<?xml`

There is a special macro for inserting XML header nodes:

```lisp
(defmacro <?xml (&rest attributes)
  "Create a new XML header with the closest enclosing element as the parent.
Attributes are handled just like in <>.

Returns the XML header node."
  ...)
```

### `<!--`

There is a special macro for inserting comments:

```lisp
(defmacro <!-- (&optional (text ""))
  "Create a comment with the closest enclosing element as the parent.

Returns the comment node."
  ...)
```

### `<!doctype`

There is a special macro for inserting doctype nodes:

```lisp
(defmacro <!doctype (doctype)
  "Create a doctype element with the closest enclosing element as the parent.

Returns the doctype node."
  ...)
```

### `<![cdata[`

There is a special macro for inserting CDATA nodes:

```lisp
(defmacro <![cdata[ (&optional (text ""))
  "Create a CDATA element with the closest enclosing element as the parent.

Returns the CDATA node."
  ...)
```

## License

    Copyright (c) 2018 Joram Schrijver

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
