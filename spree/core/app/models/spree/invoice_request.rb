module Spree
  # A consumer asking for an invoice on an order they bought as a private
  # buyer (docs/plans/6.1-invoices-and-receipts.md). Recorded whoever issues
  # the order's invoices: it is fulfilled the moment an invoice of kind
  # `invoice` is added to the order, uploaded or generated.
  class InvoiceRequest < Spree.base_class
    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::Metadata

    has_prefix_id :ireq

    # Named for the order, which is what an integration listens on; the payload
    # is the request, carrying the order id and the buyer's details.
    publishes_event 'order.invoice_requested'

    has_status :open, :fulfilled, default: :open

    belongs_to :order, class_name: 'Spree::Order', inverse_of: :invoice_requests
    belongs_to :customer, class_name: "::#{Spree.customer_class}", optional: true
    belongs_to :billing_address, class_name: 'Spree::Address', optional: true
    belongs_to :invoice, class_name: 'Spree::Invoice', optional: true, inverse_of: :invoice_request

    normalizes :company_name, with: ->(value) { value.strip.presence }
    normalizes :tax_id, with: ->(value) { value.gsub(/[\s.-]/, '').upcase.presence }

    validates :company_name, length: { maximum: 255 }
    validates :tax_id, length: { maximum: 32 }
    validate :one_open_request_per_order, on: :create

    self.whitelisted_ransackable_attributes = %w[status created_at]

    # @param invoice [Spree::Invoice]
    # @return [void]
    def fulfill!(invoice)
      update!(status: 'fulfilled', invoice: invoice)
    end

    private

    # The partial unique index is the guarantee; this gives the API a message
    # instead of a database error on the ordinary double click.
    def one_open_request_per_order
      return unless order && self.class.open.exists?(order_id: order_id)

      errors.add(:base, :invoice_request_already_open)
    end
  end
end
