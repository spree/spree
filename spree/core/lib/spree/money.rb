require 'money'

Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

module Spree
  class Money
    # An amount that is not a canonical decimal string: a JSON number, a
    # localized or padded string, or more decimals than the field allows.
    class InvalidFormat < ArgumentError
      # @return [Symbol, nil] the request field the amount came from
      attr_reader :field

      def initialize(message = nil, field: nil)
        super(message)
        @field = field
      end
    end

    # How Spree rounds an amount to a currency.
    #
    # Lives here beside the rounding mode above because "how much is this worth
    # in this currency" is one answer a store should give consistently — the
    # same two lines had otherwise been written out wherever a service needed
    # them, each copy free to drift.
    module Rounding
      module_function

      # ISO 4217 minor units, the one table Ruby and the TypeScript clients
      # share. The Money gem disagrees for a few currencies (it writes HUF
      # without decimals), so Spree reads its own copy.
      EXPONENTS = JSON.parse(File.read(File.expand_path('../../config/currency_exponents.json', __dir__))).freeze

      # Unit prices may be quoted below the minor unit ("0.0125" USD); amounts
      # that change hands never are.
      UNIT_PRICE_DECIMALS = 4

      CANONICAL_DECIMAL = /\A-?\d+(\.\d+)?\z/

      ROUNDING_MODES = {
        half_up: BigDecimal::ROUND_HALF_UP,
        half_even: BigDecimal::ROUND_HALF_EVEN,
        half_down: BigDecimal::ROUND_HALF_DOWN,
        up: BigDecimal::ROUND_UP,
        down: BigDecimal::ROUND_DOWN
      }.freeze

      # The number of decimal places a currency is written in: 2 for most, 0
      # for yen, 3 for dinar. An unknown currency falls back to two places
      # rather than raising — a sale is not the moment to discover a typo in a
      # currency code.
      #
      # Note that Spree's money columns are `decimal(_, 2)` throughout, so a
      # three-decimal currency still loses its last place on the way into the
      # database. Rounding here to the currency's own precision keeps the
      # arithmetic honest and means widening those columns would be the only
      # change needed; it does not by itself make Spree dinar-exact.
      #
      # @param currency [String, ::Money::Currency, nil]
      # @return [Integer]
      def precision(currency)
        code = currency.respond_to?(:iso_code) ? currency.iso_code : currency.to_s.upcase
        EXPONENTS[code] || ::Money::Currency.find(code)&.exponent || EXPONENTS['USD']
      end

      # Rounds to the currency's own minor unit, so amounts reconcile to the
      # cent when they are summed.
      #
      # @param amount [Numeric, String, nil]
      # @param currency [String, ::Money::Currency, nil]
      # @param mode [Symbol] one of {ROUNDING_MODES}; tax providers pick their own
      # @return [BigDecimal]
      def to_currency(amount, currency, mode: :half_up)
        quantize(amount, precision(currency), mode: mode)
      end

      # The same rounding against a precision already in hand.
      #
      # @param amount [Numeric, String, nil]
      # @param precision [Integer]
      # @param mode [Symbol] one of {ROUNDING_MODES}
      # @return [BigDecimal]
      def quantize(amount, precision, mode: :half_up)
        BigDecimal(amount.to_s).round(precision, ROUNDING_MODES.fetch(mode))
      end

      # Reads a money amount from an API request. Only a canonical decimal
      # string is accepted — never a JSON number, which may already have lost
      # precision as a float, and never more decimals than the field holds.
      #
      # @param value [String, nil]
      # @param currency [String, ::Money::Currency, nil]
      # @param unit_price [Boolean] allows up to {UNIT_PRICE_DECIMALS} decimals
      # @return [BigDecimal, nil]
      # @raise [Spree::Money::InvalidFormat]
      def parse_canonical(value, currency, unit_price: false)
        amount = parse_canonical_decimal(value)
        return if amount.nil?

        allowed = unit_price ? [precision(currency), UNIT_PRICE_DECIMALS].max : precision(currency)
        raise InvalidFormat, "has more than #{allowed} decimal places" if decimal_places(value) > allowed

        amount
      end

      # Reads a rate or percentage from an API request: a canonical decimal
      # string with no limit on its decimals.
      #
      # @param value [String, nil]
      # @return [BigDecimal, nil]
      # @raise [Spree::Money::InvalidFormat]
      def parse_canonical_decimal(value)
        return if value.nil?
        raise InvalidFormat, 'must be a decimal string like "19.99"' unless value.is_a?(String) && value.match?(CANONICAL_DECIMAL)

        BigDecimal(value)
      end

      # Reads a decimal from a caller that may send a number or text: a blank
      # is nil, a number passes, and text must be a plain decimal ("16.50"),
      # never read as a wrong number the way `"1,599.99".to_d` reads 1.
      #
      # @param value [Numeric, String, nil]
      # @return [BigDecimal, nil]
      # @raise [Spree::Money::InvalidFormat]
      def parse_decimal(value)
        return if value.blank?
        return BigDecimal(value.to_s) if value.is_a?(Numeric)

        parse_canonical_decimal(value.to_s.strip)
      end

      # Writes an amount the way the API and exports carry it: exactly the
      # currency's decimal places ("10.00", "1.500", "100"). A unit price keeps
      # up to {UNIT_PRICE_DECIMALS}, with zeros beyond the currency's own
      # places dropped ("0.0125", "19.99").
      #
      # @param amount [Numeric, String, nil]
      # @param currency [String, ::Money::Currency, nil]
      # @param unit_price [Boolean]
      # @return [String, nil]
      def format(amount, currency, unit_price: false)
        return if amount.nil?

        places = precision(currency)
        kept = unit_price ? [places, UNIT_PRICE_DECIMALS].max : places
        rounded = quantize(amount, kept)
        whole, fraction = (rounded.zero? ? BigDecimal(0) : rounded).to_s('F').split('.')
        fraction = without_trailing_zeros(fraction.to_s).ljust(places, '0')
        fraction.empty? ? whole : "#{whole}.#{fraction}"
      end

      # Writes a rate or percentage with no trailing zeros ("0.23", "23").
      #
      # @param value [Numeric, String, nil]
      # @return [String, nil]
      def format_decimal(value)
        return if value.nil?

        without_trailing_zeros(BigDecimal(value.to_s).to_s('F')).delete_suffix('.')
      end

      # Trailing zeros carry no value, so "1000.0" is a whole yen.
      def decimal_places(value)
        value.include?('.') ? without_trailing_zeros(value.split('.').last).length : 0
      end
      private_class_method :decimal_places

      # Scans back to the last other digit, in linear time on request input.
      def without_trailing_zeros(text)
        last = text.rindex(/[^0]/)
        last ? text[0..last] : ''
      end
      private_class_method :without_trailing_zeros

      # An amount as a whole number of the currency's smallest unit — cents for
      # most currencies, whole yen for one written without decimals.
      #
      # Apportionment works in these units because integers divide exactly:
      # shares computed from them can be made to sum to the original, which is
      # what keeps a divided charge equal to the one the customer agreed to.
      # Hardcoding a hundredth here instead would give a yen sale a hundred
      # times its weight and hand back a figure with decimals the currency does
      # not have.
      #
      # @param amount [Numeric, String, nil]
      # @param currency [String, ::Money::Currency, nil]
      # @return [Integer]
      def to_minor_units(amount, currency)
        (BigDecimal(amount.to_s) * (10**precision(currency))).round.to_i
      end

      # An amount in hundredths of the currency, whatever its own minor unit:
      # the unit payment gateways are called with until they take amounts with
      # their currency.
      #
      # @param amount [Numeric, String]
      # @return [Integer]
      def to_hundredths(amount)
        quantize(BigDecimal(amount.to_s) * 100, 0).to_i
      end

      # @param hundredths [Integer] as {#to_hundredths} returns
      # @return [BigDecimal]
      def from_hundredths(hundredths)
        BigDecimal(hundredths) / 100
      end

      # Whether an amount is missing or zero. Text that is not a number is
      # neither, so a malformed value is never mistaken for "nothing to pay".
      #
      # @param value [Numeric, String, nil]
      # @return [Boolean]
      def blank_or_zero?(value)
        return true if value.blank?

        BigDecimal(value.to_s, exception: false)&.zero? || false
      end

      # @param units [Integer] whole minor units, as {#to_minor_units} returns
      # @param currency [String, ::Money::Currency, nil]
      # @return [BigDecimal]
      def from_minor_units(units, currency)
        BigDecimal(units) / (10**precision(currency))
      end
    end

    include Comparable

    class << self
      attr_accessor :default_formatting_rules

      def from_cents(amount_in_cents, options = {})
        money = ::Money.from_cents(amount_in_cents, options[:currency])
        new(money.to_d, options)
      end
    end

    self.default_formatting_rules = {
      # Ruby money currently has this as false, which is wrong for the vast
      # majority of locales.
      sign_before_symbol: true
    }

    attr_reader :money

    delegate    :cents, :currency, :to_d, :positive?, :zero?, to: :money

    def initialize(amount, options = {})
      ::Money.default_currency ||= Spree::Store.default.default_currency || 'USD'
      @money   = Monetize.parse(amount, (options[:currency] || Spree::Store.default.default_currency))
      @options = Spree::Money.default_formatting_rules.merge(options)
    end

    # The amount in hundredths of the currency, whatever its own minor unit —
    # the unit payment gateways have always been called with.
    #
    # @return [Integer]
    def amount_in_cents
      Rounding.to_hundredths(to_d)
    end

    def abs
      self.class.new(money.abs, options)
    end

    def to_s
      money&.format(options)
    end

    def inspect
      "#{self.class}(cents: #{cents}, currency: #{currency})"
    end

    # 1) prevent blank, breaking spaces
    # 2) prevent escaping of HTML character entities
    def to_html(opts = { html: true })
      opts.delete(:html)

      output = money.format(options.merge(opts).merge(html_wrap: false))
      output.sub(' ', '&nbsp;').html_safe
    end

    def as_json(*)
      to_s
    end

    def decimal_mark
      options[:decimal_mark] || money.decimal_mark
    end

    def thousands_separator
      options[:thousands_separator] || money.thousands_separator
    end

    def ==(obj)
      money == obj.money
    end

    def +(other)
      result_money = money + other.money
      self.class.new(result_money.to_s, options)
    end

    def -(other)
      result_money = money - other.money
      self.class.new(result_money.to_s, options)
    end

    def *(value)
      result_money = money * value
      self.class.new(result_money.to_s, options)
    end

    def <=>(other)
      money <=> other.money
    end

    def -@
      self.class.new((-money).to_s, options)
    end

    private

    attr_reader :options
  end
end
