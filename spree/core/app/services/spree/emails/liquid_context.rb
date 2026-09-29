module Spree
  module Emails
    # `{% render %}` gives each partial a fresh, isolated context, and Liquid
    # does not carry output escaping or strict mode into it. Without this,
    # everything a partial outputs would skip HTML escaping.
    #
    # Inside a partial an argument the caller left out reads as empty, so
    # partials can take optional arguments; a misspelled field on an object
    # still raises under strict variables.
    class LiquidContext < Liquid::Context
      attr_accessor :optional_arguments, :escape_output

      def new_isolated_subcontext
        super.tap do |subcontext|
          subcontext.escape_output = escape_output
          subcontext.strict_variables = strict_variables
          subcontext.strict_filters = strict_filters
          subcontext.optional_arguments = true
        end
      end

      def find_variable(key, raise_on_not_found: true)
        super(key, raise_on_not_found: raise_on_not_found && !optional_arguments)
      end
    end
  end
end
