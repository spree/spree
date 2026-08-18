module SpreeStripe
  # Builds the suffix shown on the customer's bank statement. Stripe rejects a
  # suffix with no letters, so a purely numeric order number gets an "O#" prefix.
  class StatementDescriptorSuffixPresenter
    STATEMENT_DESCRIPTOR_MAX_CHARS = 10
    STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS = /[<>'"*\\]/.freeze
    STATEMENT_PREFIX = 'O#'.freeze

    def initialize(order_description:)
      @order_description = order_description.to_s
    end

    # @return [String, nil]
    def call
      return if stripped_order_description.blank?

      if stripped_order_description.count('A-Z').positive?
        stripped_order_description
      else
        "#{STATEMENT_PREFIX}#{stripped_order_description}"[0...STATEMENT_DESCRIPTOR_MAX_CHARS].strip
      end
    end

    private

    attr_reader :order_description

    def stripped_order_description
      @stripped_order_description ||= I18n.transliterate(order_description).
                                     gsub(STATEMENT_DESCRIPTOR_NOT_ALLOWED_CHARS, '').
                                     strip.
                                     upcase[0...STATEMENT_DESCRIPTOR_MAX_CHARS].
                                     strip
    end
  end
end
