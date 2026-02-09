require 'money'

Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

module Spree
  class Money
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
      # html option is deprecated and we need to fallback to html_wrap
      opts[:html_wrap] = opts[:html]
      opts.delete(:html)

      output = money.format(options.merge(opts))
      if opts[:html_wrap]
        output.gsub!(/<\/?[^>]*>/, '') # we don't want wrap every element in span
        output = output.sub(' ', '&nbsp;').html_safe
      end

      output
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
