module Spree
  # The buyer's tax registration — a VAT or business number, typed by kind.
  # Handed to a tax provider through {Spree::TaxProvider::Base#estimate}, where
  # it is what makes EU B2B reverse charge possible.
  #
  # Owners, exactly one per row: a customer (the durable profile value), a
  # company (the business a customer buys for), a cart (an override entered
  # during checkout) or an order (the frozen snapshot taken at completion).
  # Orders keep a copy rather than a reference because a registration can be
  # changed or withdrawn later, and an invoice must still show what was true
  # when it was issued.
  #
  # A **seller** owns one too, and it faces the other way: the others say how
  # the buyer is taxed, while a seller's registration is what the marketplace's
  # own commission invoice is made out to, and what makes EU reverse charge on
  # that fee possible (docs/plans/6.0-multi-vendor-marketplace.md Decision 12).
  #
  # == The +kind+ column
  #
  # Which registration this is — an EU VAT number, a UK one, an Australian
  # business number. Any string is accepted, and nothing here narrows it: the
  # kinds that exist are the ones somebody has a validator or a provider for,
  # and core ships one, the format check for +eu_vat+.
  #
  # It does have to match the key that validator is registered under in
  # {Spree.tax_identifier_validators}, because that lookup is by exact string. A kind
  # nothing is registered for is stored and used as entered — never
  # format-checked, never sent to a registry — and {#validatable?} reports as
  # much. So a misspelled kind fails silently rather than loudly, and a VAT
  # number filed under +vat+ rather than +eu_vat+ skips the check core does
  # ship.
  #
  # The kinds in circulation read as a region or country prefix plus the tax's
  # name: +eu_vat+, +gb_vat+, +ch_vat+, +au_abn+. Matching that spares a
  # validator gem and a storefront from having to agree with each other
  # directly. It is a habit of the gems that use it, not a rule this model
  # applies.
  class TaxIdentifier < Spree.base_class
    has_prefix_id :txi

    # Statuses the platform records rather than the buyer chooses: nil means
    # validation was never attempted, which includes having no validator
    # registered for the kind.
    VALIDATION_STATUSES = %w[pending verified unverified unavailable unsupported].freeze

    # Which link of the resolution chain produced an order's snapshot.
    SOURCES = %w[override company customer].freeze

    # Whoever holds this registration. Polymorphic rather than one nullable FK
    # per owner: there is one relationship here with two cardinalities — a
    # customer, company or seller holds one per kind, a cart or order holds
    # one — and a further owner should cost no schema change.
    belongs_to :owner, polymorphic: true

    # Whitespace and case only. Punctuation is deliberately kept: for several
    # kinds it is part of the canonical number (Switzerland's CHE-123.456.789
    # MWST, Canada's PST-1234-5678), and the buyer's own spelling is what they
    # will recognise on an invoice. A validator needing a different wire format
    # produces it itself.
    normalizes :value, with: ->(value) { value&.to_s&.gsub(/\s+/, '')&.upcase }

    # A verdict belongs to the number it answered about, so changing the number
    # ends it. Reset as part of the write, not afterwards: the response to the
    # request that made the change has to report the new state, not a stale
    # verdict or a blank one.
    before_save :reset_validation_verdict, if: :number_changing?
    after_commit :publish_number_changed, on: %i[create update]

    validates :kind, :value, presence: true
    # One per kind per owner — what the storefront upsert assumes, and what
    # makes resolution deterministic.
    validates :kind, uniqueness: { scope: [:owner_type, :owner_id] }
    # Data hygiene, not a format claim — no tax regime issues numbers this long.
    validates :value, length: { maximum: 64 }
    validates :validation_status, inclusion: { in: VALIDATION_STATUSES }, allow_nil: true
    validates :source, inclusion: { in: SOURCES }, allow_nil: true
    # An order's snapshot is a copy of a number already accepted, so a rule
    # tightened since — or a country leaving the VAT area — must not fail the
    # order it was placed on.
    validate :value_format, unless: :order_owned?
    # Registrations exist only on legal-entity nodes — a division's purchases
    # read theirs through the legal entity. A validation rather than a schema
    # difference, so a per-division foreign registration can be allowed later
    # by relaxing this alone.
    validate :company_is_legal_entity

    scope :for_kind, ->(kind) { where(kind: kind) }
    scope :verified, -> { where(validation_status: 'verified') }

    # An order-owned row is a completion snapshot: immutable once written, so
    # the tax treatment of a placed order can always be explained.
    def readonly?
      persisted? && order_owned?
    end

    def verified?
      validation_status == 'verified'
    end

    # Whether a registry can be asked about a number of this kind here. What
    # tells the admin apart the two reasons a row has no verdict: not attempted
    # yet, or nothing here knows how to ask.
    #
    # A format-only validator does not count. Core registers one for +eu_vat+,
    # so a stock install rejects a mistyped VAT number on save and still leaves
    # the verdict blank — the shape being right is not evidence that the
    # business is registered, and only a registry can supply that.
    #
    # @return [Boolean]
    def validatable?
      return false if order_owned?

      validator_class&.checks_registry? || false
    end

    private

    # An order-owned row is the frozen completion snapshot, which is what makes
    # it immutable and exempt from re-validation.
    def order_owned?
      owner_type == 'Spree::Order'
    end

    # Format knowledge lives entirely in the registered validator, so a kind
    # with none is accepted as entered: a single rule spanning every tax regime
    # on earth would be a guess, and its failure mode is turning away a real
    # business customer.
    def value_format
      # Blank is the presence validation's business; saying it twice for one
      # mistake helps nobody.
      return if value.blank?

      validator = validator_class
      return if validator.nil?
      return if validator.valid_format?(value)

      errors.add(:value, :invalid)
    end

    # The class registered for this kind, or nil when nothing is registered and
    # when what is registered cannot be loaded.
    #
    # A registry entry naming a class that is gone — an initializer left behind
    # after its gem was dropped, or a typo — used to be inert, since the lookup
    # only asked whether the key existed. It is read on every save and on every
    # admin serialization, so letting it raise would take out the whole tax
    # identifier listing over one stale line of configuration.
    def validator_class
      Spree.tax_identifier_validators[kind].presence&.to_s&.safe_constantize
    end

    def number_changing?
      !order_owned? && (will_save_change_to_value? || will_save_change_to_kind?)
    end

    # `pending` when something here can answer for the new number, and nothing at
    # all when nothing can — a kind with no validator gets no promise, and the old
    # answer cannot stay: Purchase::Taxation#best_of prefers a verified row, so a
    # stale `verified` would be actively chosen to decide tax.
    #
    # A new row has no earlier verdict to invalidate, so a number imported with one
    # already recorded keeps it.
    def reset_validation_verdict
      return if new_record? && !validatable?

      self.validation_status = validatable? ? 'pending' : nil
      self.validated_at = nil
      self.validation_evidence = nil unless validatable?
    end

    # Announces the fact; Spree::TaxIdentifierValidationSubscriber decides what
    # to do about it. Published only when the number itself changed, so the
    # verdict the check writes back cannot trigger another check.
    def publish_number_changed
      return unless saved_changes.key?('value') || saved_changes.key?('kind')

      publish_event('tax_identifier.number_changed')
    end

    # Registrations exist only on legal-entity nodes — a division's purchases
    # read theirs through the legal entity.
    def company_is_legal_entity
      return unless owner.is_a?(Spree::Company)
      return if owner.legal_entity?

      errors.add(:owner, :must_be_legal_entity)
    end
  end
end
