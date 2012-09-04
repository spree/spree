require 'money'

module Spree
  class Money
    def initialize(amount, options={})
      @money = ::Money.new(amount * 100, Spree::Config[:currency])
      @options = {}
      @options[:with_currency] = true if Spree::Config[:display_currency]
      @options[:symbol_position] = Spree::Config[:currency_symbol_position].to_sym
      @options.merge!(options)
      # Must be a symbol because the Money gem doesn't do the conversion
      @options[:symbol_position] = @options[:symbol_position].to_sym
    end

    def to_s
      @money.format(@options)
    end
  end
end
