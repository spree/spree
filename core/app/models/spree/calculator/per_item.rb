module Spree
  class Calculator::PerItem < Calculator
    preference :amount, :decimal, :default => 0
    preference :product, :product, :default => 0

    def self.description
      I18n.t(:flat_rate_per_item)
    end

    def compute(object=nil)
      quantity = object.line_items.where(:variant_id => product.variants_including_master_ids).all.collect(&:quantity).sum
      self.preferred_amount.to_f * quantity.to_f
    end

    def product
      @product ||= Product.find(preferred_product.to_i)
    end
  end
end
