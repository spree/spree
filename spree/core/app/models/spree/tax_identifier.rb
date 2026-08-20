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
  # and core ships neither.
  #
  # It does have to match the key that validator is registered under in
  # {Spree.tax_identifier_validators}, because that lookup is by exact string. A kind
  # nothing is registered for is stored and used as entered — never
  # format-checked, never sent to a registry — and {#validatable?} reports as
  # much. So a misspelled kind fails silently rather than loudly.
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

    # Owner — exactly one
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true, inverse_of: :tax_identifiers
    belongs_to :company, class_name: 'Spree::Company', optional: true, inverse_of: :tax_identifiers
    belongs_to :seller, class_name: 'Spree::Seller', optional: true, inverse_of: :tax_identifiers
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :tax_identifier
    belongs_to :order, class_name: 'Spree::Order', optional: true, inverse_of: :tax_identifier

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
    # One per kind for a customer — what the storefront upsert assumes, and what
    # makes resolution deterministic. Cart and order rows are singular by their
    # own associations.
    validates :kind, uniqueness: { scope: :customer_id }, if: -> { customer_id.present? }
    validates :kind, uniqueness: { scope: :company_id }, if: -> { company_id.present? }
    validates :kind, uniqueness: { scope: :seller_id }, if: -> { seller_id.present? }
    # Data hygiene, not a format claim — no tax regime issues numbers this long.
    validates :value, length: { maximum: 64 }
    validates :validation_status, inclusion: { in: VALIDATION_STATUSES }, allow_nil: true
    validates :source, inclusion: { in: SOURCES }, allow_nil: true
    validate :exactly_one_owner
    validate :value_format

    scope :for_kind, ->(kind) { where(kind: kind) }
    scope :verified, -> { where(validation_status: 'verified') }

    # An order-owned row is a completion snapshot: immutable once written, so
    # the tax treatment of a placed order can always be explained.
    def readonly?
      persisted? && order_id.present?
    end

    # @return [Spree::Customer, Spree::Company, Spree::Seller, Spree::Cart, Spree::Order, nil]
    def owner
      customer || company || seller || cart || order
    end

    def verified?
      validation_status == 'verified'
    end

    # Whether this installation can check a number of this kind at all. What
    # tells the admin apart the two reasons a row has no verdict: not attempted
    # yet, or nothing here knows how to ask.
    #
    # @return [Boolean]
    def validatable?
      order_id.nil? && Spree.tax_identifier_validators.key?(kind)
    end

    private

    # Format knowledge lives entirely in the registered validator. Core asserts
    # nothing about the shape of a number whose rules live in someone else's
    # statute book: a rule spanning every tax regime on earth would be a guess,
    # and its failure mode is turning away a real business customer. Kinds with
    # no validator are accepted as entered.
    def value_format
      validator = Spree.tax_identifier_validators[kind]
      return if validator.blank?
      return if validator.to_s.constantize.valid_format?(value)

      errors.add(:value, :invalid)
    end

    def number_changing?
      order_id.nil? && (will_save_change_to_value? || will_save_change_to_kind?)
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

    def exactly_one_owner
      return if [customer, company, seller, cart, order].compact.one?

      errors.add(:base, Spree.t('errors.messages.exactly_one_tax_identifier_owner'))
    end
  end
end
