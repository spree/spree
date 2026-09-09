module Spree
  # A carrier document the merchant bought through a connected carrier account
  # or uploaded after buying postage elsewhere
  # (docs/plans/6.0-shipping-labels-and-deliveries.md).
  #
  # Owned polymorphically: a +Spree::Fulfillment+ for an outbound parcel, a
  # +Spree::Return+ for the inbound one. What the merchant paid the carrier is
  # recorded here as accounting data — it never feeds the order's shipping
  # charge and never reaches a store serializer.
  #
  # Every status change is a workflow (+Spree::ShippingLabels::Purchase+,
  # +::Refund+, +::Record+); the model holds associations, validations and
  # reads only.
  class ShippingLabel < Spree.base_class
    has_prefix_id :lbl

    include Spree::SingleStoreResource
    include Spree::HasStatus
    include Spree::HasTrackingCarrier
    include Spree::Metadata

    publishes_lifecycle_events

    has_status :purchased, :refund_requested, :refunded, default: :purchased

    SOURCES = %w[purchased uploaded].freeze
    FORMATS = %w[pdf png zpl].freeze
    OWNER_TYPES = %w[Spree::Fulfillment Spree::Return].freeze
    MAX_FILE_SIZE = 10.megabytes
    # ZPL is plain text as far as any byte-sniffer can tell.
    FILE_CONTENT_TYPES = %w[application/pdf image/png text/plain].freeze

    belongs_to :owner, polymorphic: true
    belongs_to :integration, class_name: 'Spree::Integration', optional: true
    has_one :delivery, class_name: 'Spree::Delivery', inverse_of: :shipping_label, dependent: :nullify

    # Private storage: a label carries the customer's address and the
    # merchant's account details, and is served only through an
    # authenticated, streamed download.
    has_one_attached :file, service: Spree.private_storage_service_name

    validates :source, inclusion: { in: SOURCES }
    validates :owner_type, inclusion: { in: OWNER_TYPES }
    validates :format, inclusion: { in: FORMATS }, allow_blank: true
    validates :cost, numericality: { greater_than_or_equal_to: 0 }
    validates :file, size: { less_than_or_equal_to: MAX_FILE_SIZE }, if: -> { file.attached? }
    # Uploaded by sellers and staff, opened by warehouse staff — the bytes
    # decide what the file is, not the header the uploader sent.
    validates_with Spree::AttachmentContentTypeValidator,
                   attributes: [:file],
                   in: FILE_CONTENT_TYPES,
                   if: -> { file.attached? }

    normalizes :tracking_number, with: ->(value) { value&.to_s&.squish&.presence }

    # Labels that still bind a parcel: a refunded one is history.
    scope :active, -> { where.not(status: 'refunded') }
    scope :chronological, -> { order(:created_at, :id) }

    self.whitelisted_ransackable_attributes = %w[status source carrier tracking_number]

    # @return [Boolean] whether the merchant uploaded this label rather than
    #   buying it through a provider
    def uploaded?
      source == 'uploaded'
    end

    # The provider that sold this label, which is the only one that can refund
    # it. Resolved from the connected account it was bought through rather
    # than from the parcel's current delivery method: a merchant who reroutes
    # a parcel after buying postage still has to give that postage back to the
    # carrier who sold it.
    #
    # @return [Spree::FulfillmentProvider::Base]
    def provider
      klass = integration && Spree.fulfillment_providers.find do |candidate|
        candidate.integration_class.to_s == integration.type
      end

      klass ? klass.new : owner.provider
    end

    # @return [Boolean] whether a refund can still be asked of the carrier.
    #   A label the carrier is still deciding on counts: some settle refunds
    #   asynchronously and a re-ask is how a stuck one is re-driven.
    def refundable?
      !uploaded? && !refunded?
    end

    # Drops the consignment this label minted, when the parcel never moved.
    # Postage voided before anything travelled leaves nothing behind; once it
    # has travelled the journey is history and stays, label or no label.
    #
    # @return [void]
    def release_unmoved_delivery
      return if delivery.nil?
      return if owner.is_a?(Spree::Fulfillment) ? owner.fulfilled_or_delivered? : owner.received?

      delivery.destroy!
    end

    # @return [Boolean] whether the file is still to be fetched from the
    #   provider's URL
    def file_pending?
      !file.attached? && file_url.present?
    end

    # The provider's hosted copy of the label, kept only until the file has
    # been fetched into Spree's own storage.
    #
    # Answered only for an `https` URL: the value is whatever the provider
    # wrote, and it is followed by a browser on a print click and fetched
    # server-side by Spree::ShippingLabels::StoreFile, so a `javascript:` or
    # `file:` value would be an open redirect wearing a label's clothes.
    #
    # @return [String, nil]
    def file_url
      value = metadata['file_url'].to_s
      return if value.blank?

      uri = URI.parse(value)
      value if uri.is_a?(URI::HTTPS) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

    # @return [Spree::Money]
    def display_cost
      Spree::Money.new(cost, currency: currency.presence || store.default_currency)
    end

    # @return [String] the filename a download is served under
    def download_filename
      return file.filename.to_s if file.attached?

      "#{tracking_number.presence || prefixed_id}.#{format.presence || 'pdf'}"
    end

    # Custom events carry the label rather than the minimal payload; the
    # store never sees a label, so there is no storefront serializer to find
    # by convention.
    def event_serializer_class
      'Spree::Api::V3::ShippingLabelEventSerializer'.safe_constantize
    end
  end
end
