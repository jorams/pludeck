;;;; Pludeck, a friendly interface for creating a Plump DOM.
(defpackage :pludeck
  (:use :cl)
  (:export #:<>root
           #:<>wrap
           #:<>
           #:<>text
           #:<>define
           #:<?xml
           #:<!--
           #:<!doctype
           #:<![cdata[))
(in-package :pludeck)

(defvar *parent*)

(defun preprocess-body (body)
  "Wrap any element of the body that is not a list in <>text."
  (loop for form in body
        if (listp form)
          collect form
        else
          collect `(<>text ,form)
        end))

(defun parse-attributes (attributes attribute-map-sym)
  "Transform a plist of attributes into a list of calls to SETF, putting those
attributes into a Plump attribute map. Both the keys and the values are
evaluated. An evaluated key may either be a symbol, in which it is lowercased,
or any other value that can be turned into a string using PRINC-TO-STRING."
  (loop for (name value) on attributes by #'cddr
        for name-sym = (gensym)
        collect `(let ((,name-sym ,name))
                   (setf (gethash (if (symbolp ,name-sym)
                                      (string-downcase ,name-sym)
                                      (princ-to-string ,name-sym))
                                  ,attribute-map-sym)
                         (princ-to-string ,value)))))

(defmacro <>root (&body body)
  "Bind a new Plump DOM root as the parent for enclosed elements.

Note that this binding is dynamic, meaning an element constructed inside a
function called from the body will also have this DOM root as its parent.

Any non-list in the body (non-recursive) is wrapped in a call to <>TEXT.

Returns the constructed DOM root."
  `(let ((*parent* (plump:make-root)))
     (prog1 *parent*
       ,@(preprocess-body body))))

(defmacro <>wrap (parent &body body)
  "Bind the given element as the parent for enclosed elements.

Note that this binding is dynamic, meaning an element constructed inside a
function called from the body will also have this DOM root as its parent.

Any non-list in the body (non-recursive) is wrapped in a call to <>TEXT.

Returns the given parent element."
  `(let ((*parent* ,parent))
     (prog1 *parent*
       ,@(preprocess-body body))))

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
  (let ((tag (if (listp tag/attributes)
                 (first tag/attributes)
                 tag/attributes))
        (attributes (if (listp tag/attributes)
                        (rest tag/attributes)
                        ())))
    `(let ((*parent* (plump:make-element *parent* ,tag)))
       (prog1 *parent*
         ,(when attributes
            `(let ((element-attributes (plump:attributes *parent*)))
               ,@(parse-attributes attributes 'element-attributes)))
         ,@(preprocess-body body)))))

(defmacro <>text (content)
  "Create a new text node with the closest enclosing element as the parent.
CONTENT is passed to PRINC-TO-STRING.

Returns the constructed text node."
  `(plump:make-text-node *parent* (princ-to-string ,content)))

(defmacro <>define (name tag &key attributes content)
  "Define a macro to simplify construction of a specific type of DOM element.

The macro will be named NAME, and TAG will be the tag name of the elements it
produces. The arguments for this newly defined macro depend on the values of
ATTRIBUTES and CONTENT:

- If neither ATTRIBUTES nor CONTENT is true, the macro will take no arguments.

- If ATTRIBUTES is true and CONTENT is not, the macro will take attribute names
  and values as direct arguments.

- If CONTENT is true and ATTRIBUTES is not, the macro will take a body as its
  arguments. This body will get the same treatment as the one for <>.

- If both ATTRIBUTES and CONTENT are true, the macro will take a list of
  attribute names and values as its first argument, followed by a body. This
  body will similarly get the same treatment as the one for <>.
"
  `(defmacro ,name ,(cond ((and (not attributes) (not content))
                           '())
                          ((and attributes (not content))
                           '(&rest attributes))
                          ((and (not attributes) content)
                           '(&body body))
                          ((and attributes content)
                           '(attributes &body body)))
     `(<> (,',tag ,@(,@(when attributes 'attributes)))
        ,@(,@(when content 'body)))))

(defmacro <?xml (&rest attributes)
  "Create a new XML header with the closest enclosing element as the parent.
Attributes are handled just like in <>.

Returns the XML header node."
  `(let* ((header (plump:make-xml-header *parent*))
          (header-attributes (plump:attributes header)))
     (prog1 header
       ,@(parse-attributes attributes 'header-attributes))))

(defmacro <!-- (&optional (text ""))
  "Create a comment with the closest enclosing element as the parent.

Returns the comment node."
  `(plump:make-comment *parent* ,text))

(defmacro <!doctype (doctype)
  "Create a doctype element with the closest enclosing element as the parent.

Returns the doctype node."
  `(plump:make-doctype *parent* ,doctype))

(defmacro <![cdata[ (&optional (text ""))
  "Create a CDATA element with the closest enclosing element as the parent.

Returns the CDATA node."
  `(plump:make-cdata *parent* :text ,text))
