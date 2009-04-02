require 'haml/helpers/action_view_mods'
require 'haml/helpers/action_view_extensions'

module Haml
  # This module contains various helpful methods to make it easier to do
  # various tasks. Haml::Helpers is automatically included in the context
  # that a Haml template is parsed in, so all these methods are at your
  # disposal from within the template.
  module Helpers
    self.extend self

    @@action_view_defined = defined?(ActionView)
    @@force_no_action_view = false

    # Returns whether or not ActionView is installed on the system.
    def self.action_view?
      @@action_view_defined
    end

    # Note: this does *not* need to be called
    # when using Haml helpers normally
    # in Rails.
    #
    # Initializes the current object
    # as though it were in the same context
    # as a normal ActionView rendering
    # using Haml.
    # This is useful if you want to use the helpers in a context
    # other than the normal setup with ActionView.
    # For example:
    #
    #   context = Object.new
    #   class << context
    #     include Haml::Helpers
    #   end
    #   context.init_haml_helpers
    #   context.haml_tag :p, "Stuff"
    #
    def init_haml_helpers
      @haml_buffer = Haml::Buffer.new(@haml_buffer, Haml::Engine.new('').send(:options_for_buffer))
      nil
    end

    # call-seq:
    #   non_haml { ... }
    #
    # Runs a block of code in a non-Haml context
    # (i.e. #is_haml? will return false).
    #
    # This is mainly useful for rendering sub-templates such as partials in a non-Haml language,
    # particularly where helpers may behave differently when run from Haml.
    #
    # Note that this is automatically applied to Rails partials.
    def non_haml
      was_active = @haml_buffer.active?
      @haml_buffer.active = false
      yield
    ensure
      @haml_buffer.active = was_active
    end

    # call-seq:
    #   find_and_preserve(input, tags = haml_buffer.options[:preserve])
    #   find_and_preserve {...}
    #
    # Uses preserve to convert any newlines inside whitespace-sensitive tags
    # into the HTML entities for endlines.
    # @tags@ is an array of tags to preserve.
    # It defaults to the value of the <tt>:preserve</tt> option.
    def find_and_preserve(input = '', tags = haml_buffer.options[:preserve], &block)
      return find_and_preserve(capture_haml(&block)) if block

      input = input.to_s
      input.gsub(/<(#{tags.map(&Regexp.method(:escape)).join('|')})([^>]*)>(.*?)(<\/\1>)/im) do
        "<#{$1}#{$2}>#{preserve($3)}</#{$1}>"
      end
    end

    # call-seq:
    #   preserve(input)
    #   preserve {...}
    #
    # Takes any string, finds all the endlines and converts them to
    # HTML entities for endlines so they'll render correctly in
    # whitespace-sensitive tags without screwing up the indentation.
    def preserve(input = '', &block)
      return preserve(capture_haml(&block)) if block

      input.chomp("\n").gsub(/\n/, '&#x000A;').gsub(/\r/, '')
    end

    alias_method :flatten, :preserve

    # Takes an Enumerable object and a block
    # and iterates over the object,
    # yielding each element to a Haml block
    # and putting the result into <tt><li></tt> elements.
    # This creates a list of the results of the block.
    # For example:
    #
    #   = list_of([['hello'], ['yall']]) do |i|
    #     = i[0]
    #
    # Produces:
    #
    #   <li>hello</li>
    #   <li>yall</li>
    #
    # And
    #
    #   = list_of({:title => 'All the stuff', :description => 'A book about all the stuff.'}) do |key, val|
    #     %h3= key.humanize
    #     %p= val
    #
    # Produces:
    #
    #   <li>
    #     <h3>Title</h3>
    #     <p>All the stuff</p>
    #   </li>
    #   <li>
    #     <h3>Description</h3>
    #     <p>A book about all the stuff.</p>
    #   </li>
    #
    def list_of(array, &block) # :yields: item
      to_return = array.collect do |i|
        result = capture_haml(i, &block)

        if result.count("\n") > 1
          result.gsub!("\n", "\n  ")
          result = "\n  #{result.strip}\n"
        else
          result.strip!
        end

        "<li>#{result}</li>"
      end
      to_return.join("\n")
    end

    # Returns a hash containing default assignments for the xmlns and xml:lang
    # attributes of the <tt>html</tt> HTML element.
    # It also takes an optional argument for the value of xml:lang and lang,
    # which defaults to 'en-US'.
    # For example,
    #
    #   %html{html_attrs}
    #
    # becomes
    #
    #   <html xmlns='http://www.w3.org/1999/xhtml' xml:lang='en-US' lang='en-US'>
    #
    def html_attrs(lang = 'en-US')
      {:xmlns => "http://www.w3.org/1999/xhtml", 'xml:lang' => lang, :lang => lang}
    end

    # Increments the number of tabs the buffer automatically adds
    # to the lines of the template.
    # For example:
    #
    #   %h1 foo
    #   - tab_up
    #   %p bar
    #   - tab_down
    #   %strong baz
    #
    # Produces:
    #
    #   <h1>foo</h1>
    #     <p>bar</p>
    #   <strong>baz</strong>
    #
    def tab_up(i = 1)
      haml_buffer.tabulation += i
    end

    # Decrements the number of tabs the buffer automatically adds
    # to the lines of the template.
    #
    # See also tab_up.
    def tab_down(i = 1)
      haml_buffer.tabulation -= i
    end

    # Surrounds the given block of Haml code with the given characters,
    # with no whitespace in between.
    # For example:
    #
    #   = surround '(', ')' do
    #     %a{:href => "food"} chicken
    #
    # Produces:
    #
    #   (<a href='food'>chicken</a>)
    #
    # and
    #
    #   = surround '*' do
    #     %strong angry
    #
    # Produces:
    #
    #   *<strong>angry</strong>*
    #
    def surround(front, back = nil, &block)
      back ||= front
      output = capture_haml(&block)

      "#{front}#{output.chomp}#{back}\n"
    end

    # Prepends the given character to the beginning of the Haml block,
    # with no whitespace between.
    # For example:
    #
    #   = precede '*' do
    #     %span.small Not really
    #
    # Produces:
    #
    #   *<span class='small'>Not really</span>
    #
    def precede(char, &block)
      "#{char}#{capture_haml(&block).chomp}\n"
    end

    # Appends the given character to the end of the Haml block,
    # with no whitespace between.
    # For example:
    #
    #   click
    #   = succeed '.' do
    #     %a{:href=>"thing"} here
    #
    # Produces:
    #
    #   click
    #   <a href='thing'>here</a>.
    #
    def succeed(char, &block)
      "#{capture_haml(&block).chomp}#{char}\n"
    end

    # Captures the result of the given block of Haml code,
    # gets rid of the excess indentation,
    # and returns it as a string.
    # For example, after the following,
    #
    #   .foo
    #     - foo = capture_haml(13) do |a|
    #       %p= a
    #
    # the local variable <tt>foo</tt> would be assigned to "<p>13</p>\n".
    #
    def capture_haml(*args, &block)
      buffer = eval('_hamlout', block.binding) rescue haml_buffer
      with_haml_buffer(buffer) do
        position = haml_buffer.buffer.length

        block.call(*args)

        captured = haml_buffer.buffer.slice!(position..-1).split(/^/)

        min_tabs = nil
        captured.each do |line|
          tabs = line.index(/[^ ]/) || line.length
          min_tabs ||= tabs
          min_tabs = min_tabs > tabs ? tabs : min_tabs
        end

        captured.map do |line|
          line[min_tabs..-1]
        end.join
      end
    end

    def puts(*args) # :nodoc:
      warn <<END
DEPRECATION WARNING:
The Haml #puts helper is deprecated and will be removed in version 2.4.
Use the #haml_concat helper instead.
END
      haml_concat *args
    end

    # Outputs text directly to the Haml buffer, with the proper tabulation
    def haml_concat(text = "")
      haml_buffer.buffer << haml_indent << text.to_s << "\n"
      nil
    end

    # Returns the string that should be used to indent the current line
    def haml_indent
      '  ' * haml_buffer.tabulation
    end

    #
    # call-seq:
    #   haml_tag(name, *flags, attributes = {}) {...}
    #   haml_tag(name, text, *flags, attributes = {}) {...}
    #
    # Creates an HTML tag with the given name and optionally text and attributes.
    # Can take a block that will be executed
    # between when the opening and closing tags are output.
    # If the block is a Haml block or outputs text using haml_concat,
    # the text will be properly indented.
    #
    # <tt>flags</tt> is a list of symbol flags
    # like those that can be put at the end of a Haml tag
    # (<tt>:/</tt>, <tt>:<</tt>, and <tt>:></tt>).
    # Currently, only <tt>:/</tt> and <tt>:<</tt> are supported.
    #
    # For example,
    #
    #   haml_tag :table do
    #     haml_tag :tr do
    #       haml_tag :td, {:class => 'cell'} do
    #         haml_tag :strong, "strong!"
    #         haml_concat "data"
    #       end
    #       haml_tag :td do
    #         haml_concat "more_data"
    #       end
    #     end
    #   end
    #
    # outputs
    #
    #   <table>
    #     <tr>
    #       <td class='cell'>
    #         <strong>
    #           strong!
    #         </strong>
    #         data
    #       </td>
    #       <td>
    #         more_data
    #       </td>
    #     </tr>
    #   </table>
    #
    def haml_tag(name, *rest, &block)
      name = name.to_s
      text = rest.shift.to_s unless [Symbol, Hash, NilClass].any? {|t| rest.first.is_a? t}
      flags = []
      flags << rest.shift while rest.first.is_a? Symbol
      attributes = Haml::Precompiler.build_attributes(haml_buffer.html?,
                                                      haml_buffer.options[:attr_wrapper],
                                                      rest.shift || {})

      if text.nil? && block.nil? && (haml_buffer.options[:autoclose].include?(name) || flags.include?(:/))
        haml_concat "<#{name}#{attributes} />"
        return nil
      end

      if flags.include?(:/)
        raise Error.new("Self-closing tags can't have content.") if text
        raise Error.new("Illegal nesting: nesting within a self-closing tag is illegal.") if block
      end

      tag = "<#{name}#{attributes}>"
      if block.nil?
        tag << text.to_s << "</#{name}>"
        haml_concat tag
        return
      end

      if text
        raise Error.new("Illegal nesting: content can't be both given to haml_tag :#{name} and nested within it.")
      end

      if flags.include?(:<)
        tag << capture_haml(&block).strip << "</#{name}>"
        haml_concat tag
        return
      end

      haml_concat tag
      tab_up
      block.call
      tab_down
      haml_concat "</#{name}>"
      <<MESSAGE
<h1><code>haml_tag</code> outputs directly to the Haml template.
Disregard its return value and use the <code>-</code> operator.</h1>
MESSAGE
    end

    # Characters that need to be escaped to HTML entities from user input
    HTML_ESCAPE = { '&'=>'&amp;', '<'=>'&lt;', '>'=>'&gt;', '"'=>'&quot;', "'"=>'&#039;', }

    # Returns a copy of <tt>text</tt> with ampersands, angle brackets and quotes
    # escaped into HTML entities.
    def html_escape(text)
      text.to_s.gsub(/[\"><&]/) { |s| HTML_ESCAPE[s] }
    end

    # Escapes HTML entities in <tt>text</tt>, but without escaping an ampersand
    # that is already part of an escaped entity.
    def escape_once(text)
      text.to_s.gsub(/[\"><]|&(?!([a-zA-Z]+|(#\d+));)/) { |s| HTML_ESCAPE[s] }
    end

    # Returns whether or not the current template is a Haml template.
    #
    # This function, unlike other Haml::Helpers functions,
    # also works in other ActionView templates,
    # where it will always return false.
    def is_haml?
      !@haml_buffer.nil? && @haml_buffer.active?
    end

    # Returns whether or not +block+ is defined directly in a Haml template.
    def block_is_haml?(block)
      eval('_hamlout', block.binding)
      true
    rescue
      false
    end

    private

    # call-seq:
    #   with_haml_buffer(buffer) {...}
    #
    # Runs the block with the given buffer as the currently active buffer.
    def with_haml_buffer(buffer)
      @haml_buffer, old_buffer = buffer, @haml_buffer
      old_buffer.active, was_active = false, old_buffer.active? if old_buffer
      @haml_buffer.active = true
      yield
    ensure
      @haml_buffer.active = false
      old_buffer.active = was_active if old_buffer
      @haml_buffer = old_buffer
    end

    # Gets a reference to the current Haml::Buffer object.
    def haml_buffer
      @haml_buffer
    end

    # Gives a proc the same local "_hamlout" and "_erbout" variables
    # that the current template has.
    def haml_bind_proc(&proc)
      _hamlout = haml_buffer
      _erbout = _hamlout.buffer
      proc { |*args| proc.call(*args) }
    end

    include ActionViewExtensions if self.const_defined? "ActionViewExtensions"
  end
end

class Object
  # Haml overrides various ActionView helpers,
  # which call an #is_haml? method
  # to determine whether or not the current context object
  # is a proper Haml context.
  # Because ActionView helpers may be included in non-ActionView::Base classes,
  # it's a good idea to define is_haml? for all objects.
  def is_haml?
    false
  end
end

