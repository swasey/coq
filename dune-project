(lang dune 2.9)
(name coq)
(using coq 0.3)

(formatting
 (enabled_for ocaml))

; After Dune 2.8 we can use this, but let's wait for the build consolidation PR
; (generate_opam_files true)

(license LGPL-2.1-only)
(maintainers "The Coq development team <coqdev@inria.fr>")
(authors "The Coq development team, INRIA, CNRS, and contributors")
; This generates bug-reports and dev-repo
(source (github coq/coq))
(homepage https://coq.inria.fr/)
(documentation "https://coq.github.io/doc/")
(version dev)

; Note that we use coq.opam.template to have dune add the correct opam
; prefix for configure
(package
 (name coq-core)
 (depends
  (ocaml (>= 4.09.0))
  (ocamlfind (>= 1.8.1))
  (zarith (>= 1.11))
  (ounit2 :with-test))
 (depopts coq-native)
 (synopsis "The Coq Proof Assistant -- Core Binaries and Tools")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

Typical applications include the certification of properties of
programming languages (e.g. the CompCert compiler certification
project, or the Bedrock verified low-level programming library), the
formalization of mathematics (e.g. the full formalization of the
Feit-Thompson theorem or homotopy type theory) and teaching.

This package includes the Coq core binaries, plugins, and tools, but
not the vernacular standard library.

Note that in this setup, Coq needs to be started with the -boot and
-noinit options, as will otherwise fail to find the regular Coq
prelude, now living in the coq-stdlib package."))

(package
 (name coq-stdlib)
 (depends
  (coq-core (= :version)))
 (depopts coq-native)
 (synopsis "The Coq Proof Assistant -- Standard Library")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

Typical applications include the certification of properties of
programming languages (e.g. the CompCert compiler certification
project, or the Bedrock verified low-level programming library), the
formalization of mathematics (e.g. the full formalization of the
Feit-Thompson theorem or homotopy type theory) and teaching.

This package includes the Coq Standard Library, that is to say, the
set of modules usually bound to the Coq.* namespace."))

(package
 (name coqide-server)
 (depends
  (coq-core (= :version)))
 (synopsis "The Coq Proof Assistant, XML protocol server")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

This package provides the `coqidetop` language server, an
implementation of Coq's [XML protocol](https://github.com/coq/coq/blob/master/dev/doc/xml-protocol.md)
which allows clients, such as CoqIDE, to interact with Coq in a
structured way."))

(package
 (name coqide)
 (depends
  (coqide-server (= :version))
  (lablgtk3-sourceview3 (>= 3.1.2)))
 (synopsis "The Coq Proof Assistant --- GTK3 IDE")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

This package provides the CoqIDE, a graphical user interface for the
development of interactive proofs."))

(package
 (name coq-doc)
 (license "OPUBL-1.0")
 (depends
  (conf-python-3 :build)
  (coq (and :build (= :version))))
 (synopsis "The Coq Proof Assistant --- Reference Manual")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

This package provides the Coq Reference Manual."))

(package
 (name coq)
 (depends
  (coq-core (= :version))
  (coq-stdlib (= :version))
  (coqide-server (= :version)))
 (synopsis "The Coq Proof Assistant")
 (description "Coq is a formal proof management system. It provides
a formal language to write mathematical definitions, executable
algorithms and theorems together with an environment for
semi-interactive development of machine-checked proofs.

Typical applications include the certification of properties of
programming languages (e.g. the CompCert compiler certification
project, or the Bedrock verified low-level programming library), the
formalization of mathematics (e.g. the full formalization of the
Feit-Thompson theorem or homotopy type theory) and teaching."))
