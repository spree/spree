# encoding: utf-8

require 'money'

module Spree
  class Money
    class <<self
      attr_accessor :default_formatting_rules
    end

    self.default_formatting_rules = {
      # Ruby money currently has this as false, which is wrong for the vast
      # majority of locales.
      sign_before_symbol: true
    }

    attr_reader :money
    delegate    :cents, :currency, to: :money

    def initialize(amount, options = {})
      @money   = Monetize.parse([amount, (options[:currency] || Spree::Config[:currency])].join)
      @options = Spree::Money.default_formatting_rules.merge(options)
    end

    def amount_in_cents
      (cents / currency.subunit_to_unit.to_f * 100).round
    end

    def to_s
      money.format(options)
    end

    # 1) prevent blank, breaking spaces
    # 2) prevent escaping of HTML character entities
    def to_html(opts = { html: true })
      output = money.format(options.merge(opts))
      output = output.sub(' ', '&nbsp;').html_safe if opts[:html]

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

    private

    attr_reader :options
  end
end
