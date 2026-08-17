# frozen_string_literal: true

module Spree
  # What a marketplace charges a seller, as configuration.
  #
  # Rates are resolved per line item by walking a store's enabled rates in
  # list order and taking the first whose rules match
  # (Spree::Commissions::ResolveRate). A rate with no rules matches
  # everything, which is how a marketplace expresses a single default without
  # configuring anything.
  #
  # The list IS the precedence, so what an operator sees in the table is what
  # resolution does. Seeded rates arrive in the order merchants asked for —
  # product, then category, then vendor, then the marketplace default — and a
  # marketplace that wants a different answer drags a row instead of reasoning
  # about which rule type is 'narrower'.
  #
  # Mutable, unlike the Spree::CommissionLine rows it produces: editing a rate
  # changes what the next sale is charged and never what a past one was.
  class CommissionRate < Spree.base_class
    has_prefix_id :crate

    acts_as_paranoid
    # Scoped to the store: positions in one marketplace must not shuffle
    # another's, and an unscoped list on a store-owned model fails the core
    # suite for exactly that reason.
    #
    # New rates go to the top, not the bottom. A rate is created to say
    # something more specific than what is already there — and the bottom of
    # the list is where the catch-all lives, so appending would file every new
    # rate behind the one rate guaranteed to match first, leaving it dead on
    # arrival. Top-of-list means a new rate takes effect, which is what
    # creating one means.
    acts_as_list scope: :store_id, add_new_at: :top

    include Spree::SingleStoreResource
    include Spree::Metadata
    include Spree::TypedAssociations

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
    validates :value, numericality: { greater_than_or_equal_to: 0 }
    # Stored lowercase so the database enforces the same uniqueness the
    # validation promises. A functional index over LOWER(code) would be the
    # alternative, but that is a MySQL-only construct MariaDB rejects — and
    # normalizing on write means every adapter agrees without one.
    normalizes :code, with: ->(value) { value.to_s.strip.downcase.presence }

    validates :code, uniqueness: { scope: [*spree_base_uniqueness_scope, :store_id], case_sensitive: false },
                     allow_blank: true
    # A flat fee is meaningless without one; a percentage applies in any
    # currency, so it deliberately carries none.
    validates :currency, presence: true, if: :fixed?
    validates :min_amount, :max_amount, :commission_tax_rate,
              numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validate :max_amount_above_min_amount

    after_save :apply_pending_rules

    #
    # Scopes
    #
    scope :enabled, -> { where(enabled: true) }
    # The resolution order, top-down. Ties break on id so two rates sharing a
    # position resolve the same way on every read.
    scope :ordered, -> { order(position: :asc, id: :asc) }

    self.whitelisted_ransackable_attributes = %w[name code kind enabled position value currency
                                                 tax_inclusive include_shipping]
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

    # Whether this rate charges every sale, having named nothing to narrow it.
    #
    # Load-bearing for ordering, not just description: resolution stops at the
    # first match, so a global rate makes every rate below it unreachable. It
    # belongs at the bottom of the list, and an operator moving one up is
    # turning off everything beneath it.
    #
    # @return [Boolean]
    def global?
      commission_rules.empty?
    end

    # Whether this rate's rules admit the sale.
    #
    # Every rule must say yes. A rule naming several records means any of
    # them, so "(Cameras OR Audio) AND that seller" is a category rule holding
    # two ids beside a vendor rule holding one — the OR lives inside a rule,
    # which is why there is no match-policy setting to get wrong. A rate with
    # no rules charges every sale.
    #
    # @param context [Spree::Commissions::Context]
    # @return [Boolean]
    def matches?(context)
      commission_rules.all? { |rule| rule.applicable?(context) }
    end

    # The rate's targeting, under the name the API reads and writes it by.
    #
    # @return [Array<Spree::CommissionRule>]
    def rules
      commission_rules
    end

    # The flat payload the admin API writes: `[{type:, preferences: {...}}]`,
    # replacing the rate's rules wholesale. Rows update by id, new ones resolve
    # their class through the registry, and omitted ones are removed — the same
    # shape a price list's rules use.
    #
    # Ids inside a rule's preferences are scope-checked against this rate's own
    # store as they are written (see normalize_id_preference), so a rule can
    # never be pointed at another marketplace's records.
    #
    # @param rows [Array<Hash>, nil]
    # @return [void]
    def rules=(rows)
      assign_typed_association(:commission_rules, rows)
    end

    private

    # A new rate has no id for its rules to hang off until it is saved.
    def apply_pending_rules
      flush_pending_typed_association(:commission_rules)
    end

    def max_amount_above_min_amount
      return if max_amount.nil? || min_amount.nil?
      return if max_amount >= min_amount

      errors.add(:max_amount, :must_be_greater_than_min_amount)
    end
  end
end
