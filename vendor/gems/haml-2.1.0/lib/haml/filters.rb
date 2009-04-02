module Haml
  # The module containing the default filters,
  # as well as the base module,
  # Haml::Filters::Base.
  module Filters
    # Returns a hash of defined filters.
    def self.defined
      @defined ||= {}
    end

    # The base module for Haml filters.
    # User-defined filters should be modules including this module.
    #
    # A user-defined filter should override either Base#render or Base #compile.
    # Base#render is the most common.
    # It takes a string, the filter source,
    # and returns another string,
    # the result of the filter.
    # For example:
    #
    #   module Haml::Filters::Sass
    #     include Haml::Filters::Base
    #
    #     def render(text)
    #       ::Sass::Engine.new(text).render
    #     end
    #   end
    #
    # For details on overriding #compile, see its documentation.
    #
    module Base
      def self.included(base) # :nodoc:
        Filters.defined[base.name.split("::").last.downcase] = base
        base.extend(base)
        base.instance_variable_set "@lazy_requires", nil
      end

      # Takes a string, the source text that should be passed to the filter,
      # and returns the string resulting from running the filter on <tt>text</tt>.
      #
      # This should be overridden in most individual filter modules
      # to render text with the given filter.
      # If compile is overridden, however, render doesn't need to be.
      def render(text)
        raise Error.new("#{self.inspect}#render not defined!")
      end

      # Same as render, but takes the Haml options hash as well.
      # It's only safe to rely on options made available in Haml::Engine#options_for_buffer.
      def render_with_options(text, options)
        render(text)
      end

      def internal_compile(*args) # :nodoc:
        resolve_lazy_requires
        compile(*args)
      end

      # compile should be overridden when a filter needs to have access
      # to the Haml evaluation context.
      # Rather than applying a filter to a string at compile-time,
      # compile uses the Haml::Precompiler instance to compile the string to Ruby code
      # that will be executed in the context of the active Haml template.
      #
      # Warning: the Haml::Precompiler interface is neither well-documented
      # nor guaranteed to be stable.
      # If you want to make use of it,
      # you'll probably need to look at the source code
      # and should test your filter when upgrading to new Haml versions.
      def compile(precompiler, text)
        resolve_lazy_requires
        filter = self
        precompiler.instance_eval do
          if contains_interpolation?(text)
            return if options[:suppress_eval]

            push_script <<RUBY
find_and_preserve(#{filter.inspect}.render_with_options(#{unescape_interpolation(text)}, _hamlout.options))
RUBY
            return
          end

          rendered = Haml::Helpers::find_and_preserve(filter.render_with_options(text, precompiler.options), precompiler.options[:preserve])

          if !options[:ugly]
            push_text(rendered.rstrip.gsub("\n", "\n#{'  ' * @output_tabs}"))
          else
            push_text(rendered.rstrip)
          end
        end
      end

      # This becomes a class method of modules that include Base.
      # It allows the module to specify one or more Ruby files
      # that Haml should try to require when compiling the filter.
      #
      # The first file specified is tried first,
      # then the second, etc.
      # If none are found, the compilation throws an exception.
      #
      # For example:
      #
      #   module Haml::Filters::Markdown
      #     lazy_require 'rdiscount', 'peg_markdown', 'maruku', 'bluecloth'
      #
      #     ...
      #   end
      #
      def lazy_require(*reqs)
        @lazy_requires = reqs
      end

      private

      def resolve_lazy_requires
        return unless @lazy_requires

        @lazy_requires[0...-1].each do |req|
          begin
            @required = req
            require @required
            return
          rescue LoadError; end # RCov doesn't see this, but it is run
        end

        begin
          @required = @lazy_requires[-1]
          require @required
        rescue LoadError => e
          classname = self.name.match(/\w+$/)[0]

          if @lazy_requires.size == 1
            raise Error.new("Can't run #{classname} filter; required file '#{@lazy_requires.first}' not found")
          else
            raise Error.new("Can't run #{classname} filter; required #{@lazy_requires.map { |r| "'#{r}'" }.join(' or ')}, but none were found")
          end
        end
      end
    end
  end
end

# :stopdoc:

begin
  require 'rubygems'
rescue LoadError; end

module Haml
  module Filters
    module Plain
      include Base

      def render(text); text; end
    end

    module Javascript
      include Base

      def render_with_options(text, options)
        <<END
<script type=#{options[:attr_wrapper]}text/javascript#{options[:attr_wrapper]}>
  //<![CDATA[
    #{text.rstrip.gsub("\n", "\n    ")}
  //]]>
</script>
END
      end
    end

    module Cdata
      include Base

      def render(text)
        "<![CDATA[#{("\n" + text).rstrip.gsub("\n", "\n    ")}\n]]>"
      end
    end

    module Escaped
      include Base

      def render(text)
        Haml::Helpers.html_escape text
      end
    end

    module Ruby
      include Base
      lazy_require 'stringio'

      def compile(precompiler, text)
        return if precompiler.options[:suppress_eval]
        precompiler.instance_eval do
          push_silent <<-FIRST.gsub("\n", ';') + text + <<-LAST.gsub("\n", ';')
            _haml_old_stdout = $stdout
            $stdout = StringIO.new(_hamlout.buffer, 'a')
          FIRST
            _haml_old_stdout, $stdout = $stdout, _haml_old_stdout
            _haml_old_stdout.close
          LAST
        end
      end
    end

    module Preserve
      include Base

      def render(text)
        Haml::Helpers.preserve text
      end
    end

    module Sass
      include Base
      lazy_require 'sass/plugin'

      def render(text)
        ::Sass::Engine.new(text, ::Sass::Plugin.engine_options).render
      end
    end

    module ERB
      include Base
      lazy_require 'erb'

      def compile(precompiler, text)
        return if precompiler.options[:suppress_eval]
        src = ::ERB.new(text).src.sub(/^#coding:.*?\n/, '').
          sub(/^_erbout = '';/, "").gsub("\n", ';')
        precompiler.send(:push_silent, src)
      end
    end

    module Textile
      include Base
      lazy_require 'redcloth'

      def render(text)
        ::RedCloth.new(text).to_html(:textile)
      end
    end
    RedCloth = Textile
    Filters.defined['redcloth'] = RedCloth

    # Uses BlueCloth or RedCloth to provide only Markdown (not Textile) parsing
    module Markdown
      include Base
      lazy_require 'rdiscount', 'peg_markdown', 'maruku', 'bluecloth'

      def render(text)
        engine = case @required
                 when 'rdiscount'
                   ::RDiscount
                 when 'peg_markdown'
                   ::PEGMarkdown
                 when 'maruku'
                   ::Maruku
                 when 'bluecloth'
                   ::BlueCloth
                 end
        engine.new(text).to_html
      end
    end

    module Maruku
      include Base
      lazy_require 'maruku'

      def render(text)
        ::Maruku.new(text).to_html
      end
    end
  end
end

# :startdoc:
