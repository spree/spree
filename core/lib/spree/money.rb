module Spree
  class Money
    def initialize(amount)
      @amount = amount
      @money = ::Money.new(amount * 100, Spree::Config[:currency])
      @options = []
      @options << :with_currency if Spree::Config[:display_currency]
    end

    def to_s
      @money.format(*@options)
    end
  end
end
