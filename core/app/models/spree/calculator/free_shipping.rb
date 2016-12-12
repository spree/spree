module Spree
  class Calculator::FreeShipping < Calculator
    def self.description
      Spree.t(:free_shipping)
    end

    def compute(object)
      ActiveSupport::Deprecation.warn(<<-EOS, caller)
        Spree::Calculator::FreeShipping will be removed in Spree 3.3
        The only case where it was used was for Free Shipping Promotions.
        There is now a Promotion Action which deals with these types of promotions instead
      EOS
      if object.is_a?(Array)
        return if object.empty?
        order = object.first.order
      else
        order = object
      end

      order.ship_total
    end
  end
end
