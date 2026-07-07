module Spree
  # Strict, locale-independent decimal parser for money amounts written by
  # machine clients (Admin API v3, the dashboard) that always send the
  # canonical "1234.56" format — never a human-typed, locale-formatted
  # string.
  #
  # `Spree::LocalizedNumber.parse` reinterprets decimal separators based on
  # the *request's* I18n locale, which is correct for legacy Rails admin
  # forms where a human typed the value in their own locale, but wrong for
  # API payloads: the same canonical string must parse to the same amount
  # regardless of which locale happens to be active on the request. Under a
  # comma-decimal locale, `LocalizedNumber.parse("24.99")` silently strips
  # the dot and returns `2499`.
  class CanonicalNumber
    FORMAT = /\A-?\d+(\.\d{1,4})?\z/

    # Raised when a String value isn't a plain, locale-independent decimal.
    class InvalidFormat < ArgumentError; end

    # @param value [String, Numeric, nil]
    # @return [BigDecimal, nil]
    # @raise [InvalidFormat] if a String value isn't formatted as a plain
    #   decimal (optional leading `-`, digits, optional `.` + digits)
    def self.parse(value)
      return nil if value.nil?
      return BigDecimal(value.to_s) if value.is_a?(Numeric)

      str = value.to_s.strip
      return nil if str.empty?

      unless str.match?(FORMAT)
        raise InvalidFormat, "must be a plain decimal string like \"19.99\" (got #{value.inspect})"
      end

      BigDecimal(str)
    end
  end
end
