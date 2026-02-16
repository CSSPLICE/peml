
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'peml/version'

Gem::Specification.new do |spec|
  spec.name          = Peml::NAME
  spec.version       = Peml::VERSION
  spec.authors       = ['s-edwards']
  spec.email         = ['edwards@cs.vt.edu']

  spec.summary       = %q{Provides parsing of PEML, the
Programming Exercise Markup Language. Also provides for parsing of PEMLtest,
the testing DSL provided as part of PEML, as well as transformers to convert
PEMLtest descriptions into executable tests for Java and other programming
languages.}
  spec.description   = %q{The Programming Exercise Markup Language (PEML)
is intended to be a simple, easy format for CS and IT instructors of all kinds
(college, community college, high school, whatever) to describe programming
assignments and activities. We want it to be so easy (and obvious) to use that
instructors won't see it as a technological or notational barrier to
expressing their assignments.

We intend for this format to be something that authors of automated grading
tools can adopt, so they can provide a very easy, low-energy onboarding path
for existing instructors to get programming activities into such tools. As a
result, this notation leans heavily on supporting authors and streamlining
common cases, even if this may require more work on the part of tool
developers--the goal is to make it super easy for authors of programming
activities, not to fit into a specific auto-grader or simplify tasks for
tool writers.

For more details, see the PEML website.}
  spec.homepage      = 'https://cssplice.github.io/peml/'
  spec.license       = "Apache License 2.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").
      reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'bin'
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.executables   = ['peml', 'pemltest']
  spec.require_paths = ['lib']


  spec.add_development_dependency 'bundler', '~> 2.3'
  spec.add_development_dependency 'rake', '>= 13.0'
  spec.add_development_dependency 'minitest', '~> 5.0'

  spec.add_runtime_dependency 'parslet', '>= 1.8'
  spec.add_runtime_dependency 'json_schemer', '>= 0.2'
  spec.add_runtime_dependency 'redcarpet', '>= 3.5'
  spec.add_runtime_dependency 'kramdown', '~> 2.3.1'
  spec.add_runtime_dependency 'kramdown-parser-gfm', '~> 1.1.0'
  spec.add_runtime_dependency 'dottie', '~> 0.0.3'
  spec.add_runtime_dependency 'liquid', '>= 3.0.6'

  # Fetching rake 13.0.6
  # Installing rake 13.0.6
  # Fetching dottie 0.0.3 (was 0.0.2)
  # Fetching minitest 5.16.3
  # Fetching base64 0.3.0
  # Fetching bigdecimal 3.3.1
  # Fetching regexp_parser 2.11.3 (was 2.5.0)
  # Fetching simpleidn 0.2.3
  # Fetching rexml 3.4.4 (was 3.2.5)
  # Fetching redcarpet 3.6.1 (was 3.5.1)
  # Using liquid 5.3.0 (was 5.4.0)
  # Installing base64 0.3.0
  # Installing dottie 0.0.3 (was 0.0.2)
  # Installing minitest 5.16.3
  # Installing bigdecimal 3.3.1 with native extensions
  # Installing regexp_parser 2.11.3 (was 2.5.0)
  # Installing redcarpet 3.6.1 (was 3.5.1) with native extensions
  # Installing rexml 3.4.4 (was 3.2.5)
  # Installing simpleidn 0.2.3
  # Fetching json_schemer 2.2.1 (was 0.2.21)
  # Installing json_schemer 2.2.1 (was 0.2.21)

end
