module Spree
  class Promotion::Actions::CreateLineItems < PromotionAction
    has_many :promotion_action_line_items, :foreign_key => 'promotion_action_id'

    attr_accessor :line_items_string

    def perform(options = {})
      return unless order = options[:order]
      promotion_action_line_items.each do |item|
        current_quantity = order.quantity_of(item.variant)
        if current_quantity < item.quantity
          order.add_variant(item.variant, item.quantity - current_quantity)
        end
      end
    end

    def line_items_string
      promotion_action_line_items.map { |li| "#{li.variant_id}x#{li.quantity}" }.join(',')
    end

    def line_items_string=(value)
      promotion_action_line_items.destroy_all
      value.to_s.split(',').each do |str|
        variant_id, quantity = str.split('x')
        if variant_id && quantity && variant = Variant.find_by_id(variant_id)
          promotion_action_line_items.create({
            :variant => variant,
            :quantity => quantity.to_i,
          }, :without_protection => true)
        end
      end
    end
  end
end
