module Spree
  module Core
    module Emails
      # HTML-escapes what a Liquid email template prints, unless the value was
      # marked `| raw`. Applied where output is written rather than through
      # Liquid's global filter, which `{% assign %}` also runs through — that
      # would escape a value once when assigned and again when printed, and
      # turn assigned numbers and lists into strings.
      #
      # Switched on by the `escape_output` register, which Liquid hands down to
      # every partial, so any other Liquid the host app runs is untouched.
      module EscapedOutput
        def self.active?(context)
          context.registers[:escape_output]
        end

        # `{{ value }}` and `{% echo value %}`. Variables are not tags, so this
        # is the one place Liquid itself has to be extended.
        module Variable
          def render_to_output_buffer(context, output)
            return super unless EscapedOutput.active?(context)

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

        # A captured block was escaped as it rendered, so it is kept as safe
        # HTML rather than escaped a second time when printed.
        class Capture < Liquid::Capture
          def render(context)
            output = super
            EscapedOutput.active?(context) ? output.html_safe : output
          end
        end

        # `{% cycle %}` writes its values straight to the output.
        class Cycle < Liquid::Cycle
          def render_to_output_buffer(context, output)
            return super unless EscapedOutput.active?(context)

            output << ERB::Util.html_escape(super(context, +''))
          end
        end
      end
    end
  end
end

Liquid::Variable.prepend(Spree::Core::Emails::EscapedOutput::Variable)
