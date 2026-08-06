module Spree
  # Eligibility constraint on a delivery method, evaluated against the stock
  # package in the Estimator's method filter — the single seam every rate
  # consumer flows through, so calculator- and provider-priced methods obey
  # the same rules. AND semantics across a method's active rules; a method
  # with no rules is eligible everywhere.
  # See docs/plans/6.0-delivery-method-rules.md.
  class DeliveryMethodRule < Spree.base_class
    include Spree::PreferenceSchema

    has_prefix_id :dmrule

    belongs_to :delivery_method, class_name: 'Spree::DeliveryMethod',
               inverse_of: :delivery_method_rules, touch: true

    delegate :store, to: :delivery_method

    attribute :active, :boolean, default: true

    validates :type, :delivery_method, presence: true
    # One instance of each rule kind per method — duplicates would either be
    # a no-op or contradict themselves under AND semantics.
    validates :type, uniqueness: { scope: [:delivery_method_id, *spree_base_uniqueness_scope] }
    validate :type_must_be_registered

    scope :active, -> { where(active: true) }

    # Extra params a subclass accepts beyond `type`/`active`/`preferences` —
    # association-backed config declares itself here so the nested rules API
    # stays generic (mirrors {Spree::PromotionRule.additional_permitted_attributes}).
    #
    # @return [Array]
    def self.additional_permitted_attributes
      []
    end

    registers_subclasses_via { Spree.delivery_method_rules }

    # @return [String] localized display name for the rule kind, used by admin pickers
    def self.human_name
      Spree.t("delivery_method_rule_types.#{api_type}.name", default: api_type.titleize)
    end

    # @return [String] localized description for the rule kind
    def self.human_description
      Spree.t("delivery_method_rule_types.#{api_type}.description", default: '')
    end

    # @param package [Spree::Stock::Package]
    # @return [Boolean]
    def eligible?(_package)
      raise NotImplementedError, "Please implement 'eligible?(package)' in your rule: #{self.class.name}"
    end

    private

    def type_must_be_registered
      return if type.blank?
      return if Spree.delivery_method_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, Spree.t(:invalid_delivery_method_rule, scope: [:errors, :messages], default: 'is not a registered delivery method rule'))
    end
  end
end
