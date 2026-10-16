# frozen_string_literal: true

module Spree
  class CollectionRule < Spree.base_class
    include Spree::TypeLabels

    self.type_labels_scope = 'spree.collection_rule_types'

    has_prefix_id :crule

    MATCH_POLICIES = %w[is_equal_to is_not_equal_to contains does_not_contain].freeze

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :rules, touch: true

    validates :type, :value, presence: true
    validates :match_policy, inclusion: { in: MATCH_POLICIES }, presence: true

    after_commit :regenerate_collection_products,
                 if: -> { saved_change_to_value? || destroyed? || saved_change_to_match_policy? }

    delegate :store, to: :collection

    validate :type_must_be_registered

    registers_subclasses_via { Rails.application.config.spree.collection_rules }

    private

    # Guards against an arbitrary class name reaching the STI `type` column
    # through the API.
    def type_must_be_registered
      return if type.blank?
      return if Rails.application.config.spree.collection_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, :invalid_collection_rule, message: I18n.t('spree.errors.messages.invalid_collection_rule'))
    end

    def regenerate_collection_products
      collection.regenerate_products(only_once: true)
    end
  end
end
