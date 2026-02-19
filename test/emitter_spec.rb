require 'test_helper'
require 'peml/emitter'

describe Peml::Emitter do
  before do
    @emitter = Peml::Emitter.new
  end

  # ===== dotted() =====

  describe "#dotted" do
    it "joins prefix and key with dots" do
      _(@emitter.dotted(["license", "owner"], "name")).must_equal "license.owner.name"
    end

    it "returns just the key when prefix is empty" do
      _(@emitter.dotted([], "title")).must_equal "title"
    end

    it "handles single-element prefix" do
      _(@emitter.dotted(["license"], "id")).must_equal "license.id"
    end
  end

  # ===== needs_quoting?() =====

  describe "#needs_quoting?" do
    it "returns true when string contains a newline" do
      _(@emitter.needs_quoting?("line one\nline two")).must_equal true
    end

    it "returns false for a simple string" do
      _(@emitter.needs_quoting?("hello world")).must_equal false
    end

    it "returns false for an empty string" do
      _(@emitter.needs_quoting?("")).must_equal false
    end

    it "returns true for a string ending with a newline" do
      _(@emitter.needs_quoting?("hello\n")).must_equal true
    end

    it "returns true for a string with leading whitespace" do
      _(@emitter.needs_quoting?("  indented")).must_equal true
    end
  end

  # ===== emit_string() =====

  describe "#emit_string" do
    it "emits a simple key-value line for a single-line string" do
      lines = []
      @emitter.emit_string(lines, [], "title", "Hello World")
      _(lines).must_equal ["title: Hello World"]
    end

    it "uses dotted notation with a prefix" do
      lines = []
      @emitter.emit_string(lines, ["license", "owner"], "email", "a@b.com")
      _(lines).must_equal ["license.owner.email: a@b.com"]
    end

    it "emits a heredoc for a multi-line string" do
      lines = []
      @emitter.emit_string(lines, [], "instructions", "Line one\nLine two\n")
      _(lines).must_equal [
        "instructions:----------",
        "Line one\nLine two",
        "----------"
      ]
    end

    it "emits a heredoc for a string with embedded newlines" do
      lines = []
      @emitter.emit_string(lines, [], "desc", "a\nb")
      _(lines).must_equal [
        "desc:----------",
        "a\nb",
        "----------"
      ]
    end
  end

  # ===== emit_hash() =====

  describe "#emit_hash" do
    it "emits simple flat key-value pairs" do
      lines = []
      @emitter.emit_hash(lines, [], {"title" => "Test", "author" => "Me"})
      _(lines).must_equal [
        "title: Test",
        "author: Me"
      ]
    end

    it "uses dotted notation for nested hashes" do
      lines = []
      @emitter.emit_hash(lines, [], {
        "license" => {
          "id" => "cc-sa-4.0",
          "owner" => {"name" => "Alice"}
        }
      })
      _(lines).must_equal [
        "license.id: cc-sa-4.0",
        "license.owner.name: Alice"
      ]
    end

    it "uses prefix for deeper nesting" do
      lines = []
      @emitter.emit_hash(lines, ["root"], {"key" => "val"})
      _(lines).must_equal ["root.key: val"]
    end
  end

  # ===== emit_value() =====

  describe "#emit_value" do
    it "dispatches strings to emit_string" do
      lines = []
      @emitter.emit_value(lines, [], "title", "Hello")
      _(lines).must_equal ["title: Hello"]
    end

    it "dispatches hashes to emit_hash with extended prefix" do
      lines = []
      @emitter.emit_value(lines, [], "license", {"id" => "mit"})
      _(lines).must_equal ["license.id: mit"]
    end

    it "dispatches arrays to emit_array" do
      lines = []
      @emitter.emit_value(lines, [], "systems", [{"language" => "Java"}])
      _(lines).must_equal [
        "[systems]",
        "language: Java",
        "[]"
      ]
    end

    it "converts non-string scalars to strings" do
      lines = []
      @emitter.emit_value(lines, [], "count", 42)
      _(lines).must_equal ["count: 42"]
    end
  end

  # ===== emit_array() =====

  describe "#emit_array" do
    it "emits an array of hashes with scope markers" do
      lines = []
      @emitter.emit_array(lines, [], "systems", [
        {"language" => "Java", "version" => ">= 1.9"}
      ])
      _(lines).must_equal [
        "[systems]",
        "language: Java",
        "version: >= 1.9",
        "[]"
      ]
    end

    it "emits multiple array elements" do
      lines = []
      @emitter.emit_array(lines, [], "systems", [
        {"language" => "Java"},
        {"language" => "Python"}
      ])
      _(lines).must_equal [
        "[systems]",
        "language: Java",
        "language: Python",
        "[]"
      ]
    end

    it "uses dotted prefix for the scope key" do
      lines = []
      @emitter.emit_array(lines, ["assets"], "files", [
        {"name" => "test.java"}
      ])
      _(lines).must_equal [
        "[assets.files]",
        "name: test.java",
        "[]"
      ]
    end

    it "handles nested arrays within array elements with [.key] notation" do
      lines = []
      @emitter.emit_array(lines, [], "suites", [
        {
          "cases" => [
            {"stdin" => "hello", "stdout" => "world"}
          ]
        }
      ])
      _(lines).must_equal [
        "[suites]",
        "[.cases]",
        "stdin: hello",
        "stdout: world",
        "[]",
        "[]"
      ]
    end

    it "handles simple string array elements with * notation" do
      lines = []
      @emitter.emit_array(lines, [], "tags", ["easy", "beginner"])
      _(lines).must_equal [
        "[tags]",
        "* easy",
        "* beginner",
        "[]"
      ]
    end
  end

  # ===== emit() integration =====

  describe "#emit" do
    it "produces valid PEML for a minimal document" do
      value = {
        "exercise_id" => "test-001",
        "title" => "Test Exercise",
        "license" => {
          "id" => "cc-sa-4.0",
          "owner" => {
            "email" => "test@example.com",
            "name" => "Test User"
          }
        },
        "instructions" => "Write code here.\n"
      }
      result = @emitter.emit(value)
      expected = [
        "exercise_id: test-001",
        "title: Test Exercise",
        "license.id: cc-sa-4.0",
        "license.owner.email: test@example.com",
        "license.owner.name: Test User",
        "instructions:----------",
        "Write code here.",
        "----------",
        ""
      ].join("\n")
      _(result).must_equal expected
    end

    it "produces valid PEML with arrays" do
      value = {
        "title" => "Test",
        "systems" => [{"language" => "Java"}]
      }
      result = @emitter.emit(value)
      expected = [
        "title: Test",
        "[systems]",
        "language: Java",
        "[]",
        ""
      ].join("\n")
      _(result).must_equal expected
    end
  end

end
