# frozen_string_literal: true

module Spree
  # What a marketplace charges a seller, as configuration.
  #
  # Rates are resolved per line item by walking a store's enabled rates in
  # `priority` order and taking the first whose rules match
  # (Spree::Commissions::ResolveRate). A rate with no rules matches
  # everything, which is how a marketplace expresses a single default without
  # configuring anything.
  #
  # Mutable, unlike the Spree::CommissionLine rows it produces: editing a rate
  # changes what the next sale is charged and never what a past one was.
  class CommissionRate < Spree.base_class
    has_prefix_id :comrt

    acts_as_paranoid

    include Spree::SingleStoreResource
    include Spree::Metadata

    KINDS = %w[percentage fixed].freeze

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    has_many :commission_rules, class_name: 'Spree::CommissionRule', dependent: :destroy, inverse_of: :commission_rate
    # Nullified rather than destroyed: a commission line is a settlement record
    # that has to outlive the configuration it came from.
    has_many :commission_lines, class_name: 'Spree::CommissionLine', dependent: :nullify

    #
    # Validations
    #
    validates :name, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :priority, numericality: { only_integer: true }
    validates :value, numericality: { greater_than_or_equal_to: 0 }
    validates :code, uniqueness: { scope: [*spree_base_uniqueness_scope, :store_id], case_sensitive: false },
                     allow_blank: true
    # A flat fee is meaningless without one; a percentage applies in any
    # currency, so it deliberately carries none.
    validates :currency, presence: true, if: :fixed?
    validates :min_amount, :max_amount, :commission_tax_rate,
              numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :max_amount_above_min_amount

    #
    # Scopes
    #
    scope :enabled, -> { where(enabled: true) }
    # The resolution order. Ties break on id so a rate added later never
    # silently displaces an equal-priority one already in use.
    scope :by_priority, -> { order(priority: :desc, id: :asc) }

    self.whitelisted_ransackable_attributes = %w[name code kind enabled priority value currency
                                                 include_tax include_shipping]
    self.whitelisted_ransackable_associations = %w[commission_rules]

    # @return [Boolean]
    def percentage?
      kind == 'percentage'
    end

    # @return [Boolean]
    def fixed?
      kind == 'fixed'
    end

    # Whether this rate can be charged in the given currency. Only a fixed rate
    # has an opinion — a percentage is a ratio and travels.
    #
    # @param order_currency [String]
    # @return [Boolean]
    def applies_to_currency?(order_currency)
      return true if percentage?

      currency.to_s.casecmp?(order_currency.to_s)
    end

    # Whether this rate's targeting admits the given subjects.
    #
    # Rules are grouped by what they target, and the groups are ANDed while the
    # rules inside one are ORed: `{category: Cameras, category: Audio, vendor: X}`
    # reads "(Cameras OR Audio) AND vendor X". A dimension the rate says nothing
    # about is not a constraint, so a vendor-only rate matches that vendor's
    # every product.
    #
    # @param subjects [Hash{String=>Array}] subject type => the sale's records
    #   of that type, e.g. `{'Spree::Vendor' => [vendor], 'Spree::Category' => [...]}`
    # @return [Boolean]
    def matches_subjects?(subjects)
      rules_by_type = commission_rules.reject(&:global?).group_by(&:subject_type)
      return true if rules_by_type.empty?

      rules_by_type.all? do |subject_type, rules|
        candidate_ids = Array(subjects[subject_type]).compact.map { |record| record.try(:id) || record }.map(&:to_s)
        rules.any? { |rule| candidate_ids.include?(rule.subject_id.to_s) }
      end
    end

    # The flat payload the admin API writes: `[{subject_type:, subject_id:}]`,
    # replacing the rate's rules wholesale. Ids are already store-checked by
    # the controller, which is where the tenancy boundary belongs.
    #
    # @param rows [Array<Hash>, nil]
    # @return [void]
    def rules=(rows)
      self.commission_rules = Array(rows).map do |row|
        attributes = row.to_h.with_indifferent_access
        commission_rules.build(
          subject_type: attributes[:subject_type].presence,
          subject_id: attributes[:subject_id].presence
        )
      end
    end

    private

    def max_amount_above_min_amount
      return if max_amount.nil? || min_amount.nil?
      return if max_amount >= min_amount

      errors.add(:max_amount, :must_be_greater_than_min_amount)
    end
  end
end
