# frozen_string_literal: true

module Spree
  class CollectionRule < Spree.base_class
    include Spree::TypeLabels

    self.type_labels_scope = 'spree.collection_rule_types'

    has_prefix_id :crule

    MATCH_POLICIES = %w[is_equal_to is_not_equal_to contains does_not_contain greater_than less_than starts_with ends_with].freeze

    belongs_to :collection, class_name: 'Spree::Collection', inverse_of: :rules, touch: true

    validates :type, presence: true
    validates :value, presence: true, if: -> { self.class.value_required? }
    validates :match_policy, presence: true, inclusion: { in: ->(rule) { rule.class.match_policies } }
    validates :currency, inclusion: { in: ->(rule) { rule.store.supported_currencies_list.map(&:iso_code) } },
                         allow_blank: true, if: :collection

    normalizes :currency, with: ->(currency) { currency.to_s.upcase.presence }

    after_commit :regenerate_collection_products,
                 if: -> { destroyed? || saved_changes.keys.intersect?(%w[value match_policy currency preferences]) }

    delegate :store, to: :collection

    validate :type_must_be_registered

    registers_subclasses_via { Rails.application.config.spree.collection_rules }

    # The relations this rule type accepts. Subclasses narrow it; the
    # dashboard offers only these, and saving any other is refused.
    #
    # @return [Array<String>]
    def self.match_policies
      %w[is_equal_to is_not_equal_to contains does_not_contain]
    end

    # @return [Boolean] false for a rule type that takes no value (in stock)
    def self.value_required?
      true
    end

    # What the `/collection_rules/types` endpoint lists for each type,
    # beside its label and preference schema.
    #
    # @return [Array<Hash>]
    def self.types_listing
      subclasses_with_preference_schema.map do |entry|
        klass = registered_subclasses.find { |subclass| subclass.api_type == entry[:type] }
        entry.merge(match_policies: klass.match_policies, value_required: klass.value_required?)
      end
    end

    # The currency a price or sale rule evaluates in.
    #
    # @return [String]
    def rule_currency
      currency.presence || store.default_currency
    end

    # The value as the API reads and writes it. Rule types whose value names
    # a record answer its prefixed id.
    #
    # @return [String, nil]
    def api_value
      value
    end

    private

    def negated?
      match_policy.in?(%w[is_not_equal_to does_not_contain])
    end

    # Applies a positive condition, or its negation, to the scope.
    def match(scope, matching)
      negated? ? scope.where.not(id: matching.select(:id)) : scope.where(id: matching.select(:id))
    end

    # Guards against an arbitrary class name reaching the STI `type` column
    # through the API.
    def type_must_be_registered
      return if type.blank?
      return if Rails.application.config.spree.collection_rules.any? { |rule| rule.to_s == type }

      errors.add(:type, :invalid_collection_rule, message: I18n.t('spree.errors.messages.invalid_collection_rule'))
    end

    # The flag first: regeneration reads it to tell the rules apply.
    def regenerate_collection_products
      collection.sync_automatic!
      collection.regenerate_products(only_once: true)
    end
  end
end
