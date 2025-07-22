# Base class for all promotion rules
module Spree
  class PromotionRule < Spree.base_class
    belongs_to :promotion, class_name: 'Spree::Promotion', inverse_of: :promotion_rules

    delegate :stores, to: :promotion

    scope :of_type, ->(t) { where(type: t) }

    validates :promotion, presence: true
    validate :unique_per_promotion, on: :create

    def self.for(promotable)
      all.select { |rule| rule.applicable?(promotable) }
    end

    def applicable?(_promotable)
      raise 'applicable? should be implemented in a sub-class of Spree::PromotionRule'
    end

    def eligible?(_promotable, _options = {})
      raise 'eligible? should be implemented in a sub-class of Spree::PromotionRule'
    end

    # This states if a promotion can be applied to the specified line item
    # It is true by default, but can be overridden by promotion rules to provide conditions
    def actionable?(_line_item)
      true
    end

    def eligibility_errors
      @eligibility_errors ||= ActiveModel::Errors.new(self)
    end

    # Returns the human name of the promotion rule
    #
    # @return [String] eg. Currency
    def human_name
      Spree.t("promotion_rule_types.#{key}.name")
    end

    # Returns the human description of the promotion rule
    #
    # @return [String]
    def human_description
      Spree.t("promotion_rule_types.#{key}.description")
    end

    # Returns the key of the promotion rule
    #
    # @return [String] eg. currency
    def key
      type.demodulize.underscore
    end

    private

    def unique_per_promotion
      if Spree::PromotionRule.exists?(promotion_id: promotion_id, type: self.class.name)
        errors.add(:base, 'Promotion already contains this rule type')
      end
    end

    def eligibility_error_message(key, options = {})
      Spree.t(key, Hash[scope: [:eligibility_errors, :messages]].merge(options))
    end
  end
end
