# Base class for all promotion rules
module Spree
  class PromotionRule < Spree.base_class
    has_prefix_id :prorule

    registers_subclasses_via { Spree.promotions.rules }

    belongs_to :promotion, class_name: 'Spree::Promotion', inverse_of: :promotion_rules, touch: true

    delegate :stores, to: :promotion

    scope :of_type, ->(t) { where(type: t) }

    validates :type, uniqueness: { scope: [:promotion_id, *spree_base_uniqueness_scope] }

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

    def self.human_name
      Spree.t("promotion_rule_types.#{api_type}.name", default: api_type.titleize)
    end

    def self.human_description
      Spree.t("promotion_rule_types.#{api_type}.description", default: '')
    end

    def human_name = self.class.human_name
    def human_description = self.class.human_description

    # Returns the key of the promotion rule
    #
    # @return [String] eg. currency
    def key
      self.class.api_type
    end

    private

    # Resolves ids, prefixed or raw, through the promotion's store, so another
    # store's record raises instead of being linked. A rule built before its
    # promotion is known passes the ids through; its validation checks them.
    #
    # @param ids [Array<String, Integer>]
    # @param scope [ActiveRecord::Relation, nil] the store's records
    # @return [Array<Integer>]
    def ids_within_store(ids, scope)
      ids = Array(ids).reject(&:blank?)
      return ids if scope.nil?

      ids.map { |id| Spree::PrefixedId.prefixed_id?(id) ? scope.find_by_param!(id).id : scope.find(id).id }
    end

    def eligibility_error_message(key, options = {})
      Spree.t(key, Hash[scope: [:eligibility_errors, :messages]].merge(options))
    end
  end
end
