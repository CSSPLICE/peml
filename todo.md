Work items to complete on 0.1.1:

# PEML Syntax

+ Define code asset model, and build parser for it
+ Add more examples of PEML


# PEMLtest Syntax

+ Add support for variables
+ Add support for local definitions
+ Add support for subject
+ Add configuration parameter support (including remote inclusion)
+ Add description support to then clauses
  + May require slight changes to "check" suite starter,
    in order to keep syntax uniform between the two
  + Or maybe restrict then: (and check:) keywords to have
    description only on the same line, rather than on its
    own line?
  + Maybe require colon when there is a comment? And allow
    it to be omitted when there isn't one? Right now, the
    colon is purely optional?
    + But it's a bit inconsistent with the use of colons as
      key terminators?
    + Could be cleared up if clauses have to start on next
      line
+ Add support for tabular parameters in clauses in
  multiple formats:
  + Gherkin-style tables
  + CSV format
  + inline YAML or JSON?
+ Add support for input and output streaming operators
+ Add support for PEML-style heredocs for:
  + description
  + tabular data
  + I/O capture
+ Define matcher extensions for target language
  + equality
  + close to
  + regex contains
+ Define literal value factory extensions for target language
  + pairs
  + lists
  + arrays
  + maps
  + also support them in tabular data
+ Define message generation scheme


# PEMLtest Implementation

+ Implement generator for Java/JUnit
+ Implement generator for Python/PyUnit
+ Implement generator for Ruby/Minitest

