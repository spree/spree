module Spree
  # The buyer's tax registration — a VAT or business number, typed by kind.
  # Handed to a tax provider through {Spree::TaxProvider::Base#estimate}, where
  # it is what makes EU B2B reverse charge possible.
  #
  # Three owners, exactly one per row: a customer (the durable profile value), a
  # cart (an override entered during checkout) or an order (the frozen snapshot
  # taken at completion). Orders keep a copy rather than a reference because a
  # registration can be changed or withdrawn later, and an invoice must still
  # show what was true when it was issued.
  class TaxIdentifier < Spree.base_class
    has_prefix_id :txi

    include Spree::Metadata

    # Statuses the platform records rather than the buyer chooses: nil means
    # validation was never attempted, which includes having no validator
    # registered for the kind.
    VALIDATION_STATUSES = %w[pending verified unverified unavailable unsupported].freeze

    # Which link of the resolution chain produced an order's snapshot.
    SOURCES = %w[override company customer].freeze

    # Owner — exactly one
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true, inverse_of: :tax_identifiers
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :tax_identifier
    belongs_to :order, class_name: 'Spree::Order', optional: true, inverse_of: :tax_identifier

    before_validation :normalize_value
    after_commit :async_validate, on: %i[create update]

    validates :kind, :value, presence: true
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

    # @return [Spree::Customer, Spree::Cart, Spree::Order, nil]
    def owner
      customer || cart || order
    end

    def verified?
      validation_status == 'verified'
    end

    # The provider-facing shape: a provider reads the kind and the number, never
    # the ownership or the verdict.
    #
    # @return [Hash]
    def to_provider_params
      { kind: kind, value: value }
    end

    # Queues the registry check. Public for the same reason
    # {Spree::Address#async_geocode} is: an admin re-validate action calls it.
    def async_validate
      return unless should_validate?

      # update_columns, not update — this runs inside after_commit, and the
      # verdict columns are never the buyer's input.
      update_columns(validation_status: 'pending', validated_at: nil, updated_at: Time.current)
      Spree::TaxIdentifiers::ValidateJob.perform_later(id)
    end

    # Whether this installation can check a number of this kind at all. What
    # tells the admin apart the two reasons a row has no verdict: not attempted
    # yet, or nothing here knows how to ask.
    #
    # @return [Boolean]
    def validatable?
      order_id.nil? && Spree.tax_id_validators.key?(kind)
    end

    private

    # Whitespace and case only. Punctuation is deliberately kept: for several
    # kinds it is part of the canonical number (Switzerland's CHE-123.456.789
    # MWST, Canada's PST-1234-5678), and the buyer's own spelling is what they
    # will recognise on an invoice. A validator needing a different wire format
    # produces it itself.
    def normalize_value
      self.value = value&.gsub(/\s+/, '')&.upcase
    end

    # Format knowledge lives entirely in the registered validator. Core asserts
    # nothing about the shape of a number whose rules live in someone else's
    # statute book: a rule spanning every tax regime on earth would be a guess,
    # and its failure mode is turning away a real business customer. Kinds with
    # no validator are accepted as entered.
    def value_format
      validator = Spree.tax_id_validators[kind]
      return if validator.blank?
      return if validator.to_s.constantize.valid_format?(value)

      errors.add(:value, :invalid)
    end

    # Mirrors Address#should_geocode? — only when the number itself changed,
    # never for an order snapshot, and only when a validator exists. A stock
    # install registers none, so it never enqueues a job with nothing to do.
    def should_validate?
      validatable? && (saved_changes.key?('value') || saved_changes.key?('kind'))
    end

    def exactly_one_owner
      return if [customer, cart, order].compact.one?

      errors.add(:base, Spree.t('errors.messages.exactly_one_tax_identifier_owner'))
    end
  end
end
