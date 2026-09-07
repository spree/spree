module Spree
  # Somebody the merchant buys goods from. An address-book entry with a
  # purchasing history, not a party that transacts on the store — that is
  # {Spree::Seller}, the marketplace seller (decisions.md 2026-07-14).
  #
  # Suppliers belong to one store: a merchant running two storefronts keeps
  # two lists (docs/plans/6.0-inventory-operations.md, open question 2).
  class Supplier < Spree.base_class
    has_prefix_id :sup

    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Metadata

    acts_as_paranoid

    publishes_lifecycle_events

    has_many :purchase_orders, class_name: 'Spree::PurchaseOrder', inverse_of: :supplier,
                               dependent: :restrict_with_error

    validates :name, presence: true,
                     uniqueness: { scope: [:store_id, *spree_base_uniqueness_scope],
                                   conditions: -> { where(deleted_at: nil) } }
    validates :email, email: { allow_blank: true }, length: { maximum: 254, allow_blank: true }

    normalizes :email, with: ->(email) { email.strip.downcase }
    normalizes :name, :contact_name, :phone, with: ->(value) { value.strip }

    self.whitelisted_ransackable_attributes = %w[name contact_name email phone city country_code created_at]

    # The postal address, built from this row's own columns the way
    # {Spree::StockLocation#address} does. Unsaved, and blank when nothing has
    # been filled in — check {#postable?} first.
    #
    # @return [Spree::Address]
    def address
      Spree::Address.new(
        company: name,
        address1: address1,
        address2: address2,
        city: city,
        state_code: state_code,
        state_name: state_name,
        country_code: country_code,
        postal_code: postal_code,
        phone: phone
      )
    end

    # Whether there is enough of an address to put on a purchase order.
    #
    # @return [Boolean]
    def postable?
      address1.present? && city.present? && country_code.present?
    end

    def event_serializer_class
      'Spree::Api::V3::SupplierEventSerializer'.safe_constantize
    end
  end
end
