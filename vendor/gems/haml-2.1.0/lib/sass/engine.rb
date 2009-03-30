require 'strscan'
require 'sass/tree/node'
require 'sass/tree/rule_node'
require 'sass/tree/comment_node'
require 'sass/tree/attr_node'
require 'sass/tree/directive_node'
require 'sass/tree/variable_node'
require 'sass/tree/mixin_def_node'
require 'sass/tree/mixin_node'
require 'sass/tree/if_node'
require 'sass/tree/while_node'
require 'sass/tree/for_node'
require 'sass/tree/debug_node'
require 'sass/tree/file_node'
require 'sass/environment'
require 'sass/script'
require 'sass/error'
require 'haml/shared'

module Sass
  # :stopdoc:
  Mixin = Struct.new(:name, :args, :environment, :tree)
  # :startdoc:

  # This is the class where all the parsing and processing of the Sass
  # template is done. It can be directly used by the user by creating a
  # new instance and calling <tt>render</tt> to render the template. For example:
  #
  #   template = File.load('stylesheets/sassy.sass')
  #   sass_engine = Sass::Engine.new(template)
  #   output = sass_engine.render
  #   puts output
  class Engine
    include Haml::Util
    Line = Struct.new(:text, :tabs, :index, :offset, :filename, :children)

    # The character that begins a CSS attribute.
    ATTRIBUTE_CHAR  = ?:

    # The character that designates that
    # an attribute should be assigned to a SassScript expression.
    SCRIPT_CHAR     = ?=

    # The character that designates the beginning of a comment,
    # either Sass or CSS.
    COMMENT_CHAR = ?/

    # The character that follows the general COMMENT_CHAR and designates a Sass comment,
    # which is not output as a CSS comment.
    SASS_COMMENT_CHAR = ?/

    # The character that follows the general COMMENT_CHAR and designates a CSS comment,
    # which is embedded in the CSS document.
    CSS_COMMENT_CHAR = ?*

    # The character used to denote a compiler directive.
    DIRECTIVE_CHAR = ?@

    # Designates a non-parsed rule.
    ESCAPE_CHAR    = ?\\

    # Designates block as mixin definition rather than CSS rules to output
    MIXIN_DEFINITION_CHAR = ?=

    # Includes named mixin declared using MIXIN_DEFINITION_CHAR
    MIXIN_INCLUDE_CHAR    = ?+

    # The regex that matches and extracts data from
    # attributes of the form <tt>:name attr</tt>.
    ATTRIBUTE = /^:([^\s=:]+)\s*(=?)(?:\s+|$)(.*)/

    # The regex that matches attributes of the form <tt>name: attr</tt>.
    ATTRIBUTE_ALTERNATE_MATCHER = /^[^\s:]+\s*[=:](\s|$)/

    # The regex that matches and extracts data from
    # attributes of the form <tt>name: attr</tt>.
    ATTRIBUTE_ALTERNATE = /^([^\s=:]+)(\s*=|:)(?:\s+|$)(.*)/

    # Creates a new instace of Sass::Engine that will compile the given
    # template string when <tt>render</tt> is called.
    # See README.rdoc for available options.
    #
    #--
    #
    # TODO: Add current options to REFRENCE. Remember :filename!
    #
    # When adding options, remember to add information about them
    # to README.rdoc!
    #++
    #
    def initialize(template, options={})
      @options = {
        :style => :nested,
        :load_paths => ['.']
      }.merge! options
      @template = template
      @environment = Environment.new
      @environment.set_var("important", Script::String.new("!important"))
    end

    # Processes the template and returns the result as a string.
    def render
      begin
        render_to_tree.perform(@environment).to_s
      rescue SyntaxError => err
        err.sass_line = @line unless err.sass_line
        unless err.sass_filename
          err.add_backtrace_entry(@options[:filename])
        end
        raise err
      end
    end

    alias_method :to_css, :render

    protected

    def environment
      @environment
    end

    def render_to_tree
      root = Tree::Node.new(@options)
      append_children(root, tree(tabulate(@template)).first, true)
      root
    end

    private

    def tabulate(string)
      tab_str = nil
      first = true
      enum_with_index(string.gsub(/\r|\n|\r\n|\r\n/, "\n").scan(/^.*?$/)).map do |line, index|
        index += 1
        next if line.strip.empty?

        line_tab_str = line[/^\s*/]
        unless line_tab_str.empty?
          tab_str ||= line_tab_str

          raise SyntaxError.new("Indenting at the beginning of the document is illegal.", index) if first
          if tab_str.include?(?\s) && tab_str.include?(?\t)
            raise SyntaxError.new("Indentation can't use both tabs and spaces.", index)
          end
        end
        first &&= !tab_str.nil?
        next Line.new(line.strip, 0, index, 0, @options[:filename], []) if tab_str.nil?

        line_tabs = line_tab_str.scan(tab_str).size
        raise SyntaxError.new(<<END.strip.gsub("\n", ' '), index) if tab_str * line_tabs != line_tab_str
Inconsistent indentation: #{Haml::Shared.human_indentation line_tab_str, true} used for indentation,
but the rest of the document was indented using #{Haml::Shared.human_indentation tab_str}.
END
        Line.new(line.strip, line_tabs, index, tab_str.size, @options[:filename], [])
      end.compact
    end

    def tree(arr, i = 0)
      return [], i if arr[i].nil?

      base = arr[i].tabs
      nodes = []
      while (line = arr[i]) && line.tabs >= base
        if line.tabs > base
          if line.tabs > base + 1
            raise SyntaxError.new("The line was indented #{line.tabs - base} levels deeper than the previous line.", line.index)
          end

          nodes.last.children, i = tree(arr, i)
        else
          nodes << line
          i += 1
        end
      end
      return nodes, i
    end

    def build_tree(parent, line, root = false)
      @line = line.index
      node = parse_line(parent, line, root)

      # Node is a symbol if it's non-outputting, like a variable assignment,
      # or an array if it's a group of nodes to add
      return node unless node.is_a? Tree::Node

      node.line = line.index
      node.filename = line.filename

      unless node.is_a?(Tree::CommentNode)
        append_children(node, line.children, false)
      else
        node.children = line.children
      end
      return node
    end

    def append_children(parent, children, root)
      continued_rule = nil
      children.each do |line|
        child = build_tree(parent, line, root)

        if child.is_a?(Tree::RuleNode) && child.continued?
          raise SyntaxError.new("Rules can't end in commas.", child.line) unless child.children.empty?
          if continued_rule
            continued_rule.add_rules child
          else
            continued_rule = child
          end
          next
        end

        if continued_rule
          raise SyntaxError.new("Rules can't end in commas.", continued_rule.line) unless child.is_a?(Tree::RuleNode)
          continued_rule.add_rules child
          continued_rule.children = child.children
          continued_rule, child = nil, continued_rule
        end

        validate_and_append_child(parent, child, line, root)
      end

      raise SyntaxError.new("Rules can't end in commas.", continued_rule.line) if continued_rule

      parent
    end

    def validate_and_append_child(parent, child, line, root)
      unless root
        case child
        when Tree::MixinDefNode
          raise SyntaxError.new("Mixins may only be defined at the root of a document.", line.index)
        when Tree::DirectiveNode
          raise SyntaxError.new("Import directives may only be used at the root of a document.", line.index)
        end
      end

      case child
      when Array
        child.each {|c| validate_and_append_child(parent, c, line, root)}
      when Tree::Node
        parent << child
      end
    end

    def parse_line(parent, line, root)
      case line.text[0]
      when ATTRIBUTE_CHAR
        if line.text[1] != ATTRIBUTE_CHAR
          parse_attribute(line, ATTRIBUTE)
        else
          # Support CSS3-style pseudo-elements,
          # which begin with ::
          Tree::RuleNode.new(line.text, @options)
        end
      when Script::VARIABLE_CHAR
        parse_variable(line)
      when COMMENT_CHAR
        parse_comment(line.text)
      when DIRECTIVE_CHAR
        parse_directive(parent, line, root)
      when ESCAPE_CHAR
        Tree::RuleNode.new(line.text[1..-1], @options)
      when MIXIN_DEFINITION_CHAR
        parse_mixin_definition(line)
      when MIXIN_INCLUDE_CHAR
        if line.text[1].nil?
          Tree::RuleNode.new(line.text, @options)
        else
          parse_mixin_include(line, root)
        end
      else
        if line.text =~ ATTRIBUTE_ALTERNATE_MATCHER
          parse_attribute(line, ATTRIBUTE_ALTERNATE)
        else
          Tree::RuleNode.new(line.text, @options)
        end
      end
    end

    def parse_attribute(line, attribute_regx)
      if @options[:attribute_syntax] == :normal &&
          attribute_regx == ATTRIBUTE_ALTERNATE
        raise SyntaxError.new("Illegal attribute syntax: can't use alternate syntax when :attribute_syntax => :normal is set.")
      elsif @options[:attribute_syntax] == :alternate &&
          attribute_regx == ATTRIBUTE
        raise SyntaxError.new("Illegal attribute syntax: can't use normal syntax when :attribute_syntax => :alternate is set.")
      end

      name, eq, value = line.text.scan(attribute_regx)[0]

      if name.nil? || value.nil?
        raise SyntaxError.new("Invalid attribute: \"#{line.text}\".", @line)
      end
      expr = if (eq.strip[0] == SCRIPT_CHAR)
        parse_script(value, :offset => line.offset + line.text.index(value))
      else
        value
      end
      Tree::AttrNode.new(name, expr, @options)
    end

    def parse_variable(line)
      name, op, value = line.text.scan(Script::MATCH)[0]
      raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath variable declarations.", @line + 1) unless line.children.empty?
      raise SyntaxError.new("Invalid variable: \"#{line.text}\".", @line) unless name && value

      Tree::VariableNode.new(name, parse_script(value, :offset => line.offset + line.text.index(value)), op == '||=', @options)
    end

    def parse_comment(line)
      if line[1] == CSS_COMMENT_CHAR || line[1] == SASS_COMMENT_CHAR
        Tree::CommentNode.new(line, @options.merge(:silent => (line[1] == SASS_COMMENT_CHAR)))
      else
        Tree::RuleNode.new(line, @options)
      end
    end

    def parse_directive(parent, line, root)
      directive, whitespace, value = line.text[1..-1].split(/(\s+)/, 2)
      offset = directive.size + whitespace.size + 1 if whitespace

      # If value begins with url( or ",
      # it's a CSS @import rule and we don't want to touch it.
      if directive == "import" && value !~ /^(url\(|")/
        raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath import directives.", @line + 1) unless line.children.empty?
        import(value)
      elsif directive == "for"
        parse_for(line, root, value)
      elsif directive == "else"
        parse_else(parent, line, value)
      elsif directive == "while"
        raise SyntaxError.new("Invalid while directive '@while': expected expression.") unless value
        Tree::WhileNode.new(parse_script(value, :offset => offset), @options)
      elsif directive == "if"
        raise SyntaxError.new("Invalid if directive '@if': expected expression.") unless value
        Tree::IfNode.new(parse_script(value, :offset => offset), @options)
      elsif directive == "debug"
        raise SyntaxError.new("Invalid debug directive '@debug': expected expression.") unless value
        raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath debug directives.", @line + 1) unless line.children.empty?
        offset = line.offset + line.text.index(value).to_i
        Tree::DebugNode.new(parse_script(value, :offset => offset), @options)
      else
        Tree::DirectiveNode.new(line.text, @options)
      end
    end

    def parse_for(line, root, text)
      var, from_expr, to_name, to_expr = text.scan(/^([^\s]+)\s+from\s+(.+)\s+(to|through)\s+(.+)$/).first

      if var.nil? # scan failed, try to figure out why for error message
        if text !~ /^[^\s]+/
          expected = "variable name"
        elsif text !~ /^[^\s]+\s+from\s+.+/
          expected = "'from <expr>'"
        else
          expected = "'to <expr>' or 'through <expr>'"
        end
        raise SyntaxError.new("Invalid for directive '@for #{text}': expected #{expected}.", @line)
      end
      raise SyntaxError.new("Invalid variable \"#{var}\".", @line) unless var =~ Script::VALIDATE

      parsed_from = parse_script(from_expr, :offset => line.offset + line.text.index(from_expr))
      parsed_to = parse_script(to_expr, :offset => line.offset + line.text.index(to_expr))
      Tree::ForNode.new(var[1..-1], parsed_from, parsed_to, to_name == 'to', @options)
    end

    def parse_else(parent, line, text)
      previous = parent.last
      raise SyntaxError.new("@else must come after @if.") unless previous.is_a?(Tree::IfNode)

      if text
        if text !~ /^if\s+(.+)/
          raise SyntaxError.new("Invalid else directive '@else #{text}': expected 'if <expr>'.", @line)
        end
        expr = parse_script($1, :offset => line.offset + line.text.index($1))
      end

      node = Tree::IfNode.new(expr, @options)
      append_children(node, line.children, false)
      previous.add_else node
      nil
    end

    # parses out the arguments between the commas and cleans up the mixin arguments
    # returns nil if it fails to parse, otherwise an array.
    def parse_mixin_arguments(arg_string)
      arg_string = arg_string.strip
      return [] if arg_string.empty?
      return nil unless (arg_string[0] == ?( && arg_string[-1] == ?))
      arg_string = arg_string[1...-1]
      arg_string.split(",", -1).map {|a| a.strip}
    end

    def parse_mixin_definition(line)
      name, arg_string = line.text.scan(/^=\s*([^(]+)(.*)$/).first
      args = parse_mixin_arguments(arg_string)
      raise SyntaxError.new("Invalid mixin \"#{line.text[1..-1]}\".", @line) if name.nil? || args.nil?
      default_arg_found = false
      required_arg_count = 0
      args.map! do |arg|
        raise SyntaxError.new("Mixin arguments can't be empty.", @line) if arg.empty? || arg == "!"
        unless arg[0] == Script::VARIABLE_CHAR
          raise SyntaxError.new("Mixin argument \"#{arg}\" must begin with an exclamation point (!).", @line)
        end
        arg, default = arg.split(/\s*=\s*/, 2)
        required_arg_count += 1 unless default
        default_arg_found ||= default
        raise SyntaxError.new("Invalid variable \"#{arg}\".", @line) unless arg =~ Script::VALIDATE
        raise SyntaxError.new("Required arguments must not follow optional arguments \"#{arg}\".", @line) if default_arg_found && !default
        default = parse_script(default, :offset => line.offset + line.text.index(default)) if default
        { :name => arg[1..-1], :default_value => default }
      end
      Tree::MixinDefNode.new(name, args, @options)
    end

    def parse_mixin_include(line, root)
      name, arg_string = line.text.scan(/^\+\s*([^(]+)(.*)$/).first
      args = parse_mixin_arguments(arg_string)
      raise SyntaxError.new("Illegal nesting: Nothing may be nested beneath mixin directives.", @line + 1) unless line.children.empty?
      raise SyntaxError.new("Invalid mixin include \"#{line.text}\".", @line) if name.nil? || args.nil?
      args.each {|a| raise SyntaxError.new("Mixin arguments can't be empty.", @line) if a.empty?}

      Tree::MixinNode.new(name, args.map {|s| parse_script(s, :offset => line.offset + line.text.index(s))}, @options)
    end

    def parse_script(script, options = {})
      line = options[:line] || @line
      offset = options[:offset] || 0
      Script.parse(script, line, offset, @options[:filename])
    end

    def import_paths
      paths = @options[:load_paths] || []
      paths.unshift(File.dirname(@options[:filename])) if @options[:filename]
      paths
    end

    def import(files)
      files.split(/,\s*/).map do |filename|
        engine = nil

        begin
          filename = self.class.find_file_to_import(filename, import_paths)
        rescue Exception => e
          raise SyntaxError.new(e.message, @line)
        end

        next Tree::DirectiveNode.new("@import url(#{filename})", @options) if filename =~ /\.css$/

        File.open(filename) do |file|
          new_options = @options.dup
          new_options[:filename] = filename
          engine = Sass::Engine.new(file.read, new_options)
        end

        begin
          root = engine.render_to_tree
        rescue Sass::SyntaxError => err
          err.add_backtrace_entry(filename)
          raise err
        end
        Tree::FileNode.new(filename, root.children, @options)
      end.flatten
    end

    def self.find_file_to_import(filename, load_paths)
      was_sass = false
      original_filename = filename

      if filename[-5..-1] == ".sass"
        filename = filename[0...-5]
        was_sass = true
      elsif filename[-4..-1] == ".css"
        return filename
      end

      new_filename = find_full_path("#{filename}.sass", load_paths)

      return new_filename if new_filename
      return filename + '.css' unless was_sass
      raise SyntaxError.new("File to import not found or unreadable: #{original_filename}.", @line)
    end

    def self.find_full_path(filename, load_paths)
      segments = filename.split(File::SEPARATOR)
      segments.push "_#{segments.pop}"
      partial_name = segments.join(File::SEPARATOR)
      load_paths.each do |path|
        [partial_name, filename].each do |name|
          full_path = File.join(path, name)
          if File.readable?(full_path)
            return full_path
          end
        end
      end
      nil
    end
  end
end
