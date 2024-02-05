module Spree
  class PromotionDuplicatorCore
    def initialize(promotion, random_string: generate_random_string(4))
      @promotion = promotion
      @random_string = random_string
    end

    def duplicate
      raise NotImplementedError
    end

    private

    def copy_rules(new_promotion)
      @promotion.promotion_rules.each do |rule|
        new_rule = rule.dup
        new_promotion.promotion_rules << new_rule

        new_rule.users = rule.users if rule.try(:users)
        new_rule.taxons = rule.taxons if rule.try(:taxons)
        new_rule.products = rule.products if rule.try(:products)
      end
    end

    def generate_random_string(number)
      charset = Array('A'..'Z') + Array('a'..'z')
      Array.new(number) { charset.sample }.join
    end

    def copy_actions(new_promotion)
      @promotion.promotion_actions.each do |action|
        new_action = action.dup
        new_action.calculator = action.calculator.dup if action.try(:calculator)

        new_promotion.promotion_actions << new_action

        next unless action.try(:promotion_action_line_items)

        action.promotion_action_line_items.each do |item|
          new_action.promotion_action_line_items << item.dup
        end
      end
    end
  end
end
