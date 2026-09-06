# frozen_string_literal: true

module Spree
  # One condition on a Spree::CommissionRate: the rate applies to this sale
  # only if every one of its rules says so.
  #
  # Typed like Spree::PriceRule and Spree::DeliveryMethodRule, and for the same
  # reason. A rule that could only name a record — this seller, this category —
  # left everything else unsayable: a price band, a channel, a promotional
  # window. Each of those was a schema migration and an edit to the matcher.
  # As a class it is a subclass and a registration.
  #
  # AND across rules, and a rule holding several ids means any of them, so
  # "(Cameras OR Audio) AND that seller" is two rules rather than a policy
  # setting. A rate with no rules charges every sale.
  class CommissionRule < Spree.base_class
    include Spree::PreferenceSchema

    has_prefix_id :crule

    # Retired rather than deleted, with its rate or on its own as an operator
    # edits a rate's conditions. A commission line is a settlement record, and
    # "why was this charged" is answered by the rule that matched — which has
    # to still be readable once the rule no longer applies to anything.
    acts_as_paranoid

    belongs_to :commission_rate, class_name: 'Spree::CommissionRate',
                                 inverse_of: :commission_rules, touch: true

    # Rules reach the store through their rate, which is what lets a rule's
    # own reference lists be scope-checked against it.
    delegate :store, to: :commission_rate, allow_nil: true

    validates :type, presence: true
    # One of each kind per rate: a second rule of the same kind would either
    # repeat the first or contradict it, and under AND semantics contradiction
    # means the rate silently never applies.
    #
    # Among live rules only, matching the partial index. Retired rules are
    # history, and a replacement is saved before the rule it supersedes is
    # retired — counting those would refuse every edit.
    validates :type, uniqueness: {
      scope: [:commission_rate_id, *spree_base_uniqueness_scope],
      conditions: -> { where(deleted_at: nil) }
    }
    validate :type_must_be_registered

    registers_subclasses_via { Spree.commission_rules }

    # @return [String] the name an operator picks this rule kind by
    def self.human_name
      Spree.t("commission_rule_types.#{api_type}.name", default: name.demodulize.titleize)
    end

    # @return [String] what the rule does, shown beside the name in the picker
    def self.description
      Spree.t("commission_rule_types.#{api_type}.description", default: '')
    end

    # Whether this rule admits the sale.
    #
    # @param context [Spree::Commissions::Context]
    # @return [Boolean]
    def applicable?(context)
      raise NotImplementedError, "#{self.class.name} must implement #applicable?"
    end

    private

    def type_must_be_registered
      return if type.blank?
      return if Spree.commission_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, :invalid_commission_rule, message: Spree.t('errors.messages.invalid_commission_rule'))
    end
  end
end
