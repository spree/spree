require_dependency 'spree/calculator'

module Spree
  class Calculator::TieredPercent < Calculator
    preference :tiers, :hash, default: {}

    validates :preferred_tiers, length: { maximum: 5 }

    def self.description
      Spree.t(:tiered_percent)
    end

    def compute(object)
      range, percent = preferred_tiers.detect{ |r,_| r === object.amount }
      (object.amount * (percent || 0) / 100).round(2)
    end
  end
end
