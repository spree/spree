module Spree
  # One consignment's carrier journey — a parcel, or three pallets under one
  # PRO number — with the tracking number, carrier and the carrier's own
  # status axis (docs/plans/6.0-shipping-labels-and-deliveries.md).
  #
  # Owned polymorphically by a +Spree::Fulfillment+ (outbound) or a
  # +Spree::Return+ (inbound), and optionally minted by a shipping label. The
  # owner's own lifecycle never lives here: a fulfillment is +delivered+ when
  # every one of its deliveries is, and that rollup belongs to
  # +Spree::Deliveries::UpdateTracking+.
  #
  # +status+ is data the carrier reports, written by that workflow. It has no
  # transition graph: carriers resend the whole picture on every update.
  class Delivery < Spree.base_class
    has_prefix_id :dlv

    include Spree::SingleStoreResource

    publishes_lifecycle_events

    STATUSES = %w[
      pending pre_transit in_transit out_for_delivery available_for_pickup
      delivered return_to_sender failure unknown
    ].freeze
    OWNER_TYPES = %w[Spree::Fulfillment Spree::Return].freeze

    belongs_to :owner, polymorphic: true
    belongs_to :shipping_label, class_name: 'Spree::ShippingLabel', optional: true, inverse_of: :delivery

    attribute :status, :string, default: 'pending'

    validates :tracking_number, presence: true, uniqueness: { scope: [:owner_type, :owner_id] }
    validates :status, inclusion: { in: STATUSES }
    validates :owner_type, inclusion: { in: OWNER_TYPES }

    normalizes :tracking_number, with: ->(value) { value&.to_s&.squish&.presence }

    # Numbers from the big carriers encode who they belong to; pinning the
    # detected carrier means the badge and the URL survive when the merchant
    # only pasted a number. Fills a blank only — a merchant's or a provider's
    # explicit carrier is never second-guessed, and a forwarder's name is a
    # legal value: nothing validates +carrier+ against the registry.
    before_validation :detect_carrier, if: -> { carrier.blank? && tracking_number.present? }

    scope :chronological, -> { order(:created_at, :id) }
    scope :delivered, -> { where(status: 'delivered') }
    scope :undelivered, -> { where.not(status: 'delivered') }

    self.whitelisted_ransackable_attributes = %w[tracking_number carrier status]

    STATUSES.each do |value|
      define_method(:"#{value}?") { status == value }
    end

    # The public page where this consignment can be followed, best answer
    # first: a link the merchant pasted or the provider's tracker page (the
    # column), the pinned carrier's registered tracking page, the delivery
    # method's configured format, then detection from the number's format.
    #
    # @return [String, nil]
    def tracking_url
      return if tracking_number.blank?

      super.presence ||
        (tracking_number if pasted_link?) ||
        provider_tracking_url.presence ||
        carrier_tracking_url.presence ||
        delivery_method_tracking_url.presence ||
        detected_tracking_url
    end

    # The carrier's display name — from the registry when the key is known,
    # otherwise the free text as entered.
    #
    # @return [String, nil]
    def carrier_name
      return if carrier.blank?

      Spree.tracking_carriers.dig(carrier, :name) || carrier
    end

    # @return [Boolean] whether the tracking value is a full link rather than a number
    def pasted_link?
      tracking_number.to_s.start_with?('https://', 'http://')
    end

    private

    def provider_tracking_url
      return unless owner.respond_to?(:provider)

      owner.provider.tracking_url(self)
    end

    def carrier_tracking_url
      template = Spree.tracking_carriers.dig(carrier.to_s, :url)
      template&.gsub(':tracking', ERB::Util.url_encode(tracking_number))
    end

    def delivery_method_tracking_url
      return unless owner.respond_to?(:delivery_method)

      owner.delivery_method&.build_tracking_url(tracking_number)
    end

    def detected_tracking_url
      service = Spree.tracking_number_service.new(tracking_number.upcase)
      service.tracking_url if service.valid?
    end

    def detect_carrier
      return if pasted_link?

      service = Spree.tracking_number_service.new(tracking_number.upcase)
      self.carrier = service.tracking.courier_code.to_s if service.valid?
    end
  end
end
