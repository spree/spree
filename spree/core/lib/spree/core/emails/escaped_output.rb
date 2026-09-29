module Spree
  module Core
    module Emails
      # HTML-escapes what a Liquid email template prints, unless the value was
      # marked `| raw`. Applied where output is written rather than through
      # Liquid's global filter, which `{% assign %}` also runs through — that
      # would escape a value once when assigned and again when printed, and
      # turn assigned numbers and lists into strings.
      #
      # Only active inside a Spree email render; any other Liquid the host app
      # runs is untouched.
      module EscapedOutput
        def render_to_output_buffer(context, output)
          return super unless context.respond_to?(:escape_output) && context.escape_output

          write_escaped(render(context), output)
          output
        end

        private

        def write_escaped(value, output)
          case value
          when nil then nil
          when Array then value.each { |item| write_escaped(item, output) }
          else output << ERB::Util.html_escape(Liquid::Utils.to_s(value))
          end
        end
      end
    end
  end
end

Liquid::Variable.prepend(Spree::Core::Emails::EscapedOutput)
