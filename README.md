# PEML: The Programming Exercise Markup Language

This repository contains the **"peml" ruby gem**, a parser for PEML.

The **Programming Exercise Markup Language (PEML)** (feedback on
name choice is welcome!) is intended to be a simple, easy format for
CS and IT instructors of all kinds (college, community college, high
school, whatever) to describe programming assignments and activities.
We want it to be so easy (and obvious) to use that instructors won't
see it as a technological or notational barrier to expressing their
assignments.

We intend for this format to be something that authors of automated
grading tools can adopt, so they can provide a very easy, low-energy
onboarding path for existing instructors to get programming activities
into such tools. As a result, this notation leans heavily on supporting
authors and streamlining common cases, even if this may require more
work on the part of tool developers--the goal is to make it super easy
for **authors** of programming activities, not to fit into a specific
auto-grader or simplify tasks for tool writers.

## Documentation for PEML

For full details on PEML, see:

https://CSSPLICE.github.io/peml/


## Try PEML Live

You can try out PEML in your browser using our live, interactive parser
here:

https://discovery.cs.vt.edu/peml-live


## REST API for Parsing PEML

If you are working on an application and want to make use of PEML,
but do not want to use the Ruby parser implementation in this gem
or you prefer to use a different programming language, you can use
the parser via our REST API from the **PEML Live!** website. Documentation
is available at:

https://discovery.cs.vt.edu/peml-live/api


## Installing the Gem

Add this line to your application's Gemfile:

```ruby
gem 'peml', :github => 'CSSPLICE/peml'
```

And then execute:

    $ bundle

Or install it using the gem command (may require you to clone the repository
and build your own local copy of the gem to install).

## Usage

```
require 'peml'

Peml.parse(peml: "string containing a PEML description")

Peml.parse(filename: "file_name.peml")
```

The result returned by the `parse()` function is a hash
containing two key/value pairs, where `value` is the
parsed result of the PEML input in nested hash form, and
`diagnostics` contains an array of any diagnostic messages
(errors or other validation messages) produced.

The following additional arguments can be provided as named
parameters:

**result_only** (boolean)
<br/>
Indicate whether to return just the parse result (true), or (the default) a
hash of the form `{ value: <parse_result>, diagnostics: [<messages>] }`.

**interpolate** (boolean) (not yet implemented)
<br/>
Indicate whether or not to interpolate variables embedded in
PEML field values.

**render_to_html** (boolean) (not yet implemented)
<br/>
Indicate whether PEML fields containing markdown/markup values
should be rendered to HTML in the result.

**inline** (boolean) (not yet implemented)
<br/>
Indicate whether to inline field contents in the PEML description when the
value is specified as a URL.

**format** (string)
<br/>
This parameter indicates the format requested for the response, which is
one of (json, yaml, xml). This can be specified as an explicit parameter
named "format" passed in the request, or can be specified directly in the
request URL as a file name extension (e.g., requesting
from <code>https://discovery.cs.vt.edu/peml-live/api/parse.yaml?...</code>).
If not explicitly provided, it will be inferred through the "Accept:"
headers provided in the request, or defaults to json if not specified
anywhere else.
See the <a href="https://github.com/ruby-grape/grape">grape</a>
gem's <a href="https://github.com/ruby-grape/grape#api-formats">discussion
of API formats</a> for more details about how the format of the
response is determined.

Eventually, we'll also add support for:

```
require 'peml'

Peml.to_peml(some_nested_hash)
=> string containing exercise rendered in PEML format

my_exercise.to_peml
=> string containing exercise rendered in PEML format
```

... but these don't work yet.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/CSSPLICE/peml.
