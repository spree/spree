# Base class for all promotion rules
module Spree
  class PromotionRule < Spree.base_class
    has_prefix_id :prorule

    belongs_to :promotion, class_name: 'Spree::Promotion', inverse_of: :promotion_rules, touch: true

    delegate :stores, to: :promotion

    scope :of_type, ->(t) { where(type: t) }

    validates :promotion, presence: true
    validate :unique_per_promotion, on: :create

    # Per-subclass permitted attributes beyond `type` and `preferences`.
    # Override in STI subclasses that accept association IDs (e.g.
    # Rules::Product needs `product_ids`). The Admin API merges these
    # into its `params.permit(...)` allowlist.
    def self.additional_permitted_attributes
      []
    end

    # Builds a `parse_on_set:` lambda for `preference :foo_ids, :array`
    # declarations on rules that accept prefixed IDs from the API.
    # Splits comma-separated entries, strips whitespace, and decodes
    # any prefixed IDs to raw IDs (so eligibility checks compare
    # against `belongs_to` foreign keys directly).
    #
    # When `klass` is nil, prefixed-ID decoding is skipped — used for
    # ISO/string-keyed preferences where the value is the identifier.
    def self.normalize_id_preference(klass: nil)
      lambda do |values|
        Array(values).flat_map { |v| v.to_s.split(',') }.compact_blank.map do |v|
          v = v.strip
          if klass && Spree::PrefixedId.prefixed_id?(v)
            klass.find_by_param!(v).id.to_s
          else
            v
          end
        end
      end
    end

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
