# PEML Project Overview

PEML (Programming Exercise Markup Language) is a Ruby-based project designed to provide a simple, easy format for instructors to describe programming assignments and activities. It includes a parser, a testing DSL (PEMLtest), and tools to convert these descriptions into executable tests.

## Architecture and Main Components

- **Peml Module (`lib/peml.rb`)**: The main entry point for the library. Provides methods like `Peml.parse` and `Peml.validate`.
- **PEML Loader (`lib/peml/loader.rb`)**: A custom scanner/parser that processes the high-level PEML structure (key-value pairs, scopes, arrays).
- **PEMLtest Parser (`lib/peml/parser.rb`)**: A `parslet`-based parser for the PEMLtest domain-specific language used to define test cases.
- **Datadriven Test Renderer (`lib/peml/datadriven_test_renderer.rb`)**: Generates language-specific test code (Ruby, Python, Java, C++) from tabular data in PEML files using Liquid templates located in `lib/peml/templates/`.
- **PIF (Programming Instruction Format) (`lib/pif/`)**: A sub-component for parsing and converting PIF descriptions, including a converter to Runestone format.
- **Schema Validation**: Uses JSON Schema (`lib/peml/schema/PEML.json`) to validate the structure of parsed PEML data.

## Technologies Used

- **Ruby**: The primary programming language.
- **Parslet**: Used for the PEMLtest DSL parser.
- **JSON Schemer**: For validating parsed data against the PEML JSON Schema.
- **Liquid**: For rendering language-specific test templates.
- **Dottie**: For easy manipulation of nested hash structures.
- **Minitest**: The testing framework used for the project's own test suite.
- **Kramdown/Redcarpet**: For handling Markdown content within PEML fields.

## Key Files

- `lib/peml.rb`: Entry point for the gem.
- `lib/peml/loader.rb`: Core PEML parser logic.
- `lib/peml/parser.rb`: PEMLtest DSL parser.
- `lib/peml/schema/PEML.json`: The formal definition of the PEML format.
- `bin/peml`, `bin/pemltest`, `bin/pif`: Command-line utilities.

## Building and Running

### Prerequisites
- Ruby (version specified in `.ruby-version` if present)
- Bundler

### Installation
```bash
bundle install
```

### Running Tests
The project uses `rake` to manage tests:
```bash
bundle exec rake test
```
Individual tests can be run using `ruby`:
```bash
ruby -Ilib:test test/peml_test.rb
```

### CLI Usage
You can use the provided binaries to parse files:
```bash
bundle exec bin/peml test/peml/01-minimal.peml
bundle exec bin/pemltest test/PEMLtest/check_001.pemltest
```

## Development Conventions

- **Parsing**: The project mixes a custom line-based scanner (`Loader`) with a formal PEG parser (`Parslet`) for different parts of the format.
- **Validation**: Always validate parsed output against the schema using `Peml.validate`.
- **Templates**: Language-specific test generation should utilize the Liquid templates in `lib/peml/templates/`.
- **Testing**: New features should include corresponding test cases in `test/` and sample files in `test/peml/` or `test/PEMLtest/`.
