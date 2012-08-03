require 'money'

module Spree
  class Money
    def initialize(amount, options={})
      @money = ::Money.new(amount * 100, Spree::Config[:currency])
      @options = {}
      @options[:with_currency] = true if Spree::Config[:display_currency]
      @options.merge!(options)
    end

    def to_s
      @money.format(@options)
    end
  end
end
