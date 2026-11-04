module Spree
  # Condition on whether a payment method is offered at storefront checkout,
  # evaluated against the cart or order through
  # {Spree::PaymentMethod#eligible_for_order?}. AND semantics across a
  # method's active rules; a method with no rules is offered everywhere.
  # Back-office payments bypass rules.
  # See docs/plans/6.1-payment-method-rules.md.
  class PaymentMethodRule < Spree.base_class
    include Spree::PreferenceSchema
    include Spree::TypeLabels

    self.type_labels_scope = 'spree.payment_method_rule_types'

    has_prefix_id :pmrule

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod',
               inverse_of: :payment_method_rules, touch: true

    delegate :store, to: :payment_method

    attribute :active, :boolean, default: true

    validates :type, presence: true
    # One instance of each rule kind per method — duplicates would either be
    # a no-op or contradict themselves under AND semantics.
    validates :type, uniqueness: { scope: [:payment_method_id, *spree_base_uniqueness_scope] }
    validate :type_must_be_registered

    scope :active, -> { where(active: true) }

    registers_subclasses_via { Spree.payment_method_rules }

    # Rules read the purchase's own columns, never Spree::Current, so a job or
    # webhook evaluates them the same way a request does.
    #
    # @param purchase [Spree::Cart, Spree::Order]
    # @return [Boolean]
    def eligible?(_purchase)
      raise NotImplementedError, "Please implement 'eligible?(purchase)' in your rule: #{self.class.name}"
    end

    private

    def type_must_be_registered
      return if type.blank?
      return if Spree.payment_method_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, :invalid_payment_method_rule, message: I18n.t('spree.errors.messages.invalid_payment_method_rule'))
    end
  end
end
