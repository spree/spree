module Spree
  module Emails
    # `{% render %}` gives each partial a fresh, isolated context, and Liquid
    # does not carry strict mode into it.
    #
    # Inside a partial an argument the caller left out reads as empty, so
    # partials can take optional arguments; a misspelled field on an object
    # still raises under strict variables.
    class LiquidContext < Liquid::Context
      attr_accessor :optional_arguments

      def new_isolated_subcontext
        super.tap do |subcontext|
          subcontext.strict_variables = strict_variables
          subcontext.strict_filters = strict_filters
          subcontext.optional_arguments = true
        end
      end

      def find_variable(key, raise_on_not_found: true)
        super(key, raise_on_not_found: raise_on_not_found && !optional_arguments)
      end

      # Captured text is already-escaped HTML. A filter over it keeps it that
      # way, the same rule `SafeBuffer#+` follows: plain string arguments are
      # escaped going in and the string that comes out stays marked safe, so
      # `{{ greeting | upcase }}` is not escaped a second time when printed.
      def invoke(method, *args)
        input = args.first
        return super unless registers[:escape_output] && input.is_a?(ActiveSupport::SafeBuffer)

        escaped = args.drop(1).map { |arg| arg.is_a?(String) ? ERB::Util.html_escape(arg) : arg }
        result = super(method, input, *escaped)
        result.is_a?(String) ? result.html_safe : result
      end
    end
  end
end
