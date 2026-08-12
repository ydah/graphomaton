# Security policy

## Supported versions

Security fixes are made on `main` and released in the latest published gem. Older
releases do not receive separate backports unless a release announcement says
otherwise.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for
[`ydah/graphomaton`](https://github.com/ydah/graphomaton/security/advisories/new).
If that channel is unavailable, contact the maintainer using the email address in
the gemspec. Do not include secrets or exploit details in a public issue.

Include the affected version or commit, a minimal reproduction, expected impact,
and any known mitigations. You should receive an acknowledgement within seven
days.

## Trust boundaries

Graphomaton accepts user-controlled labels and metadata, but deliberately limits
the contexts into which they are emitted:

- YAML aliases are disabled by default. JSON and YAML parsers enforce byte, state,
  and transition limits; applications may lower those limits.
- SVG and DOT links accept HTTP, HTTPS, mail links, relative paths, and fragments.
  Executable, data, and local-file URL schemes are rejected.
- SVG style properties and theme values use allowlists. Raw CSS, external resource
  references, and declaration-breaking values are rejected.
- Mermaid HTML uses strict mode and an exact Mermaid version. Remote script assets
  require HTTPS. Offline mode requires a local classic `.js` asset.
- `inline_mermaid: true` embeds a complete local JavaScript file. Treat that file
  as executable code and enable the option only for a trusted asset.
- Graphviz, librsvg, and ImageMagick are external native programs. Calls have
  process-group timeouts and bounded output, but deployments should still patch
  those programs and run untrusted conversions with OS-level isolation.

Atomic writes protect existing output from partial exporter failures. They do not
provide authorization or path isolation; callers remain responsible for choosing
an allowed destination.
