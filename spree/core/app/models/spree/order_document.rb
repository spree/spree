module Spree
  # Paperwork on an order that is not an invoice: the buyer's PO, a
  # specification, a shipping document (docs/plans/6.1-b2b-order-documents.md).
  # Private by default; staff decide what the buyer sees. Invoices are never
  # stored here — they are Spree::Invoice records.
  class OrderDocument < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::Metadata

    has_prefix_id :odoc

    publishes_lifecycle_events

    MAX_FILE_SIZE = 10.megabytes
    # How many documents a buyer may add to one order from the storefront,
    # where a publishable key and an order are all it takes.
    MAX_CUSTOMER_UPLOADS = 20
    CONTENT_TYPES = Spree::Purchase::PurchaseOrder::PO_DOCUMENT_CONTENT_TYPES

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :order_documents
    belongs_to :uploaded_by, polymorphic: true, optional: true

    has_private_document :file, content_types: CONTENT_TYPES, max_size: MAX_FILE_SIZE, required: true

    normalizes :label, with: ->(value) { value.strip }

    validates :label, presence: true, length: { maximum: 255 }
    # A buyer's own upload is theirs to see; staff cannot hide it from them.
    validate :buyer_upload_stays_visible, if: :uploaded_by_customer?
    validate :within_customer_upload_limit, on: :create, if: :uploaded_by_customer?

    scope :customer_visible, -> { where(customer_visible: true) }

    self.whitelisted_ransackable_attributes = %w[label customer_visible created_at]

    private

    def buyer_upload_stays_visible
      errors.add(:customer_visible, :invalid) unless customer_visible?
    end

    def within_customer_upload_limit
      return if order.nil? || order.order_documents.where(uploaded_by_customer: true).count < MAX_CUSTOMER_UPLOADS

      errors.add(:base, :order_document_limit_reached, count: MAX_CUSTOMER_UPLOADS)
    end
  end
end
