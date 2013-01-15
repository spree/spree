module Spree
  class OrderPopulator
    attr_accessor :order, :currency
    attr_reader :errors

    def initialize(order, currency)
      @order = order
      @currency = currency
      @errors = ActiveModel::Errors.new(self)
    end

    #
    # Parameters can be passed using the following possible parameter configurations:
    #
    # * Single variant/quantity pairing
    # +:variants => { variant_id => quantity }+
    #
    # * Multiple products at once
    # +:products => { product_id => variant_id, product_id => variant_id }, :quantity => quantity+
    # +:products => { product_id => variant_id, product_id => variant_id }, :quantity => { variant_id => quantity, variant_id => quantity }+
    def populate(from_hash)
      from_hash[:products].each do |product_id,variant_id|
        attempt_cart_add(variant_id, from_hash[:quantity])
      end if from_hash[:products]

      from_hash[:variants].each do |variant_id, quantity|
        attempt_cart_add(variant_id, quantity)
      end if from_hash[:variants]

      valid?
    end

    def valid?
      errors.empty?
    end

    private

    def attempt_cart_add(variant_id, quantity)
      quantity = quantity.to_i
      variant = Spree::Variant.find(variant_id)
      if quantity > 0
        if check_stock_levels(variant, quantity)
          @order.add_variant(variant, quantity, currency)
        end
      end
    end

    def check_stock_levels(variant, quantity)
      display_name = %Q{#{variant.name}}
      display_name += %Q{ (#{variant.options_text})} unless variant.options_text.blank?

      if variant.available?
        on_hand = variant.on_hand
        if on_hand >= quantity || Spree::Config[:allow_backorders]
          return true
        else
          errors.add(:base, %Q{There are only #{on_hand} of #{display_name.inspect} remaining.} +
                            %Q{ Please select a quantity less than or equal to this value.})
          return false
        end
      else
        errors.add(:base, %Q{#{display_name.inspect} is out of stock.})
        return false
      end
    end
  end
end
