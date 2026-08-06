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

    validates :kind, :value, presence: true
    validates :validation_status, inclusion: { in: VALIDATION_STATUSES }, allow_nil: true
    validates :source, inclusion: { in: SOURCES }, allow_nil: true
    validate :exactly_one_owner

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

    private

    def exactly_one_owner
      return if [customer, cart, order].compact.one?

      errors.add(:base, Spree.t('errors.messages.exactly_one_tax_identifier_owner'))
    end
  end
end
