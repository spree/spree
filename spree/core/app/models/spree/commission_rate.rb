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
    # What a flat fee charges, one row per currency. A rate with no amount for
    # the sale's currency does not apply to it (see #applies_to_currency?).
    has_many :commission_rate_values, class_name: 'Spree::CommissionRateValue',
             dependent: :destroy, inverse_of: :commission_rate

    # Retired with the rate, not deleted: rules are paranoid too, so a soft
    # delete cascades to a soft delete and the rate's conditions stay readable
    # beside the commission lines they explain.
    has_many :commission_rules, class_name: 'Spree::CommissionRule',
             dependent: :destroy, inverse_of: :commission_rate
    # Never cascaded: a commission line is a settlement record, and "which rate
    # charged this" has to stay answerable after the rate is retired. The rate
    # itself is still readable through `with_deleted`, which is the point of
    # soft-deleting it rather than removing it.
    has_many :commission_lines, class_name: 'Spree::CommissionLine', dependent: nil

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
    # A floor or a cap is an amount, so a percentage rate carrying one is no
    # longer free to travel — "at least 5" means 5 of something. A flat fee
    # says the same thing through its per-currency amounts instead.
    validates :currency, presence: true, if: -> { percentage? && (min_amount.present? || max_amount.present?) }
    # A flat fee that charges nothing anywhere would be skipped for every sale,
    # which reads as a rate that does not work rather than one that is off.
    validate :fixed_rate_states_an_amount
    validates :min_amount, :max_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    # A fraction, bounded like the store preference it overrides: the number is
    # multiplied straight into what a seller is charged, so a figure above 1
    # would bill more tax than fee — which is exactly what an operator
    # reasoning in percent would enter.
    validates :commission_tax_rate,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true
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

    # Whether this rate can be charged in the given currency. A rate has an
    # opinion when it carries an amount — a flat fee, or a floor or cap on a
    # percentage.
    #
    # @param order_currency [String]
    # @return [Boolean]
    def applies_to_currency?(order_currency)
      # A flat fee applies only where it has stated an amount. Falling through
      # to the next rate is deliberate: converting one currency's figure into
      # another would invent a fee nobody set.
      return amount_for(order_currency).present? if fixed?

      # A percentage is a ratio and travels — unless it carries a floor or a
      # cap, which are amounts and only mean something in their own currency.
      return true if currency.blank?

      currency.to_s.casecmp?(order_currency.to_s)
    end

    # The flat fee in one currency, or nil where none is set.
    #
    # @param order_currency [String]
    # @return [BigDecimal, nil]
    def amount_for(order_currency)
      commission_rate_values.
        find { |value| value.currency.to_s.casecmp?(order_currency.to_s) }&.amount
    end

    # The flat fee amounts as the API reads and writes them: currency => amount.
    #
    # @return [Hash{String=>BigDecimal}]
    def amounts
      commission_rate_values.to_h { |value| [value.currency, value.amount] }
    end

    # Replaces the flat fee amounts wholesale. A currency left out is retired,
    # which is how a marketplace stops charging this rate there.
    #
    # @param values [Hash, nil] currency => amount
    # @return [void]
    def amounts=(values)
      @pending_amounts = (values || {}).to_h.transform_keys { |key| key.to_s.upcase }
      apply_pending_amounts if persisted?
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
      # Destroyed rather than assigned away, so clearing retires the rules
      # instead of trying to null a non-null column.
      return commission_rules.destroy_all if persisted? && Array(rows).empty?

      assign_typed_association(:commission_rules, identify_existing_rules(rows))
    end

    private

    # Points each incoming row at the rule of its kind the rate already has.
    #
    # There is one rule per kind, so a payload naming a kind means "this is
    # what that condition should now say" — but a row without an `id` builds a
    # new rule, which then collides with the live one it was meant to replace.
    # Clients send the whole set without ids (the dashboard rebuilds it from
    # form state), so identifying by kind is what makes an edit an edit.
    def identify_existing_rules(rows)
      return rows unless persisted?

      existing = commission_rules.index_by { |rule| rule.class.api_type }

      Array(rows).map do |row|
        attributes = row.respond_to?(:to_h) ? row.to_h.with_indifferent_access : row
        next row if attributes[:id].present?

        match = existing[attributes[:type].to_s]
        match ? attributes.merge(id: match.id) : row
      end
    end

    # A new rate has no id for its rules to hang off until it is saved.
    def apply_pending_rules
      flush_pending_typed_association(:commission_rules)
      apply_pending_amounts
    end

    def apply_pending_amounts
      return if @pending_amounts.nil?

      wanted = @pending_amounts.compact_blank
      @pending_amounts = nil

      commission_rate_values.reject { |value| wanted.key?(value.currency) }.each(&:destroy)
      wanted.each do |currency, amount|
        row = commission_rate_values.find { |value| value.currency == currency } ||
              commission_rate_values.build(currency: currency)
        row.update!(amount: amount)
      end
      commission_rate_values.reset
    end

    def fixed_rate_states_an_amount
      return unless fixed?
      return if @pending_amounts.present? || commission_rate_values.any?

      errors.add(:base, Spree.t('errors.messages.commission_rate_needs_an_amount'))
    end

    def max_amount_above_min_amount
      return if max_amount.nil? || min_amount.nil?
      return if max_amount >= min_amount

      errors.add(:max_amount, Spree.t('errors.messages.must_be_greater_than_min_amount'))
    end
  end
end
