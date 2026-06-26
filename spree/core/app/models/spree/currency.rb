module Spree
  # Virtual model for a currency. Wraps a currency +code+ (ISO 4217) and exposes
  # its display name and select label — the single home for that logic instead
  # of being restated in helpers. Mirrors +Spree::Locale+.
  class Currency
    include ActiveModel::Model
    include Comparable

    # @!attribute code
    #   @return [String] the currency code, e.g. "USD", "EUR"
    attr_accessor :code

    # Display name, e.g. "United States Dollar". Falls back to the code for an
    # unknown currency.
    # @return [String]
    def name
      # `find` returns nil (it does not raise) for unknown codes.
      ::Money::Currency.find(code.to_s.upcase)&.name || code.to_s.upcase
    end

    # Select label, e.g. "USD — United States Dollar".
    # @return [String]
    def label
      upper = code.to_s.upcase
      return upper if name.blank? || name.casecmp?(code.to_s)

      "#{upper} — #{name}"
    end

    def to_s
      code.to_s.upcase
    end

    # Compare/equality by code so a Currency slots into string-keyed collections.
    def <=>(other)
      to_s <=> other.to_s
    end

    def eql?(other)
      other.is_a?(Spree::Currency) && to_s == other.to_s
    end

    def hash
      to_s.hash
    end
  end
end
