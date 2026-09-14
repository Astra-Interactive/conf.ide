## Package layout

Where a source file lives is an architectural decision, not a filing decision. A package is a unit of
change and a unit of visibility. This rule says which package a type belongs to. Language-specific rules
say how files inside a package are cut.

Terms used below, whatever the language calls them:

- **package** — a named group of source files that share a namespace and a visibility boundary.
- **build unit** — a separately compiled part of the project with its own declared dependency list.

### The rule of two levels

1. **Top level = business concept.** The first level of directories names bounded contexts, aggregates
   or features of the domain: `order`, `backup`, `snapshot`, `repository`. Never a technical layer
   (`models`, `services`, `dto`, `errors`, `utils`) and never a framework or tool.
2. **Second level = layer, only if needed.** Inside a concept, split into `domain` / `application` /
   `infrastructure` only when that concept has enough logic to need it. A CRUD-like concept stays flat.
3. **A layer becomes a top-level unit only when it is a build unit.** A build unit named `domain`,
   `ports`, `application` or `<adapter>` exists so the compiler enforces the dependency rule: the domain
   cannot import the database because the database is not in its dependency list. Inside such a build
   unit, go back to rule 1: packages are concepts again.

```
<project>/                         build units = layers (only where the compiler must enforce them)
├── domain/
│   ├── backup/                    package = concept; contains the plan, its progress, its summary
│   ├── repository/                the id, the name, the config, the backends
│   │   └── backend/               a sub-concept large enough to get its own package
│   └── restore/
├── ports/
├── application/
├── <adapter>/                     one build unit per external technology
└── app/                           composition root
```

A flat directory with dozens of files on one level means a concept level is missing. Group them.

### What goes together

Apply Martin's component principles when deciding whether two types share a package:

| Principle | Decision rule |
|---|---|
| Common Closure (CCP) | Types that change for the same reason and at the same time live together. A value, its error type, its parser, its builder are one concept. |
| Common Reuse (CRP) | Do not make a client depend on a package for one type and drag in ten it does not use. If only one type is shared, it is in the wrong package. |
| Acyclic Dependencies (ADP) | Packages form a DAG. A cycle means two concepts are really one, or a shared piece must move down. |
| Stable Dependencies (SDP) | Depend towards the stable side: adapters depend on ports, ports on domain, never back. |
| Stable Abstractions (SAP) | Stable packages (domain, ports) hold abstractions and values; unstable ones (adapters, UI, main) hold concrete implementations. |

Group by reason to change, never by kind of type. `errors/`, `dto/`, `types`, `utils` collect unrelated
things that change independently and violate CCP.

### Visibility is part of the layout

A package boundary only means something when most of what is inside is hidden.

- Each package exposes a minimal API: the types other packages actually use. Everything else is private
  to the package, using whatever the language offers for that.
- The composition root is the only place that sees every concrete implementation.
- Prefer the compiler over reviews: a build-unit boundary is enforced for free; a package-only boundary
  needs an architecture test or a linter.

### Naming

- The package name is the qualifier, the type name is the concept: `order.Error`, not
  `order.OrderError`.
- Package names are domain words from the ubiquitous language, in the casing the language prescribes.
  No `common`, `shared`, `misc`, `helpers` unless the content really is a shared kernel with a documented
  reason to exist.

### Checklist before adding or moving a file

1. Which business concept does this type belong to? That is its package.
2. Does the package's existing content change for the same reasons as this type? If not, new package.
3. After adding it, does any dependency now point from a stable package towards a less stable one, or
   form a cycle? If yes, the type belongs one level down or behind a port.
4. Does the type need to be visible outside the package? If not, it is not public.
5. Is the top level of the tree still readable as a description of the domain, not of the tech stack?
