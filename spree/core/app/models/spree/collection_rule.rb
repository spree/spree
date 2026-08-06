# frozen_string_literal: true

module Spree
  class CollectionRule < Spree.base_class
    has_prefix_id :crule

    MATCH_POLICIES = %w[is_equal_to is_not_equal_to contains does_not_contain].freeze

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :rules, touch: true

    validates :collection, :type, :value, presence: true
    validates :match_policy, inclusion: { in: MATCH_POLICIES }, presence: true

    after_commit :regenerate_collection_products,
                 if: -> { saved_change_to_value? || destroyed? || saved_change_to_match_policy? }

    delegate :store, to: :collection

    validate :type_must_be_registered

    # @return [String] localized display name for the rule kind, used by admin pickers
    def self.human_name
      Spree.t("collection_rule_types.#{api_type}.name", default: api_type.titleize)
    end

    # @return [String] localized description for the rule kind
    def self.human_description
      Spree.t("collection_rule_types.#{api_type}.description", default: '')
    end

    # Feeds the `description` field of `subclasses_with_preference_schema`
    # (the `/types` discovery payload), which only reads `.description`.
    def self.description
      human_description
    end

    def human_name = self.class.human_name
    def human_description = self.class.human_description

    registers_subclasses_via { Rails.application.config.spree.collection_rules }

    private

    # Guards against an arbitrary class name reaching the STI `type` column
    # through the API.
    def type_must_be_registered
      return if type.blank?
      return if Rails.application.config.spree.collection_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, Spree.t(:invalid_collection_rule, scope: [:errors, :messages],
                                                          default: 'is not a registered collection rule'))
    end

    def regenerate_collection_products
      collection.regenerate_products(only_once: true)
    end
  end
end
