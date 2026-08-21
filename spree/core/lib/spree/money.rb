require 'money'

Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

module Spree
  class Money
    # How Spree rounds an amount to a currency.
    #
    # Lives here beside the rounding mode above because "how much is this worth
    # in this currency" is one answer a store should give consistently — the
    # same two lines had otherwise been written out wherever a service needed
    # them, each copy free to drift.
    module Rounding
      module_function

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
        (::Money::Currency.find(currency) || ::Money::Currency.find('USD')).exponent
      end

      # Rounds to the currency's own minor unit, half-up, so amounts reconcile
      # to the cent when they are summed.
      #
      # @param amount [Numeric, String, nil]
      # @param currency [String, ::Money::Currency, nil]
      # @return [BigDecimal]
      def to_currency(amount, currency)
        quantize(amount, precision(currency))
      end

      # The same rounding against a precision already in hand.
      #
      # @param amount [Numeric, String, nil]
      # @param precision [Integer]
      # @return [BigDecimal]
      def quantize(amount, precision)
        BigDecimal(amount.to_s).round(precision, BigDecimal::ROUND_HALF_UP)
      end

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

    def amount_in_cents
      (cents / currency.subunit_to_unit.to_f * 100).round
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
