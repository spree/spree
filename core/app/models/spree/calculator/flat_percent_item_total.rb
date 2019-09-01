require_dependency 'spree/calculator'

module Spree
  class Calculator::FlatPercentItemTotal < Calculator
    preference :flat_percent, :decimal, default: 0

    def self.description
      Spree.t(:flat_percent)
    end

    def compute(object)
      compute(object)
    end

    delegate :compute, to: :percent_calculator

    private

    def percent_calculator
      ::Spree::Calculator::PercentOnLineItem.new(preferred_percent: preferred_flat_percent)
    end
  end
end
