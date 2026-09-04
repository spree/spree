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
    include Spree::HasTrackingCarrier

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
    # An emptied carrier or link is a cleared column, not an empty string —
    # a blank carrier is what asks for detection to run again.
    normalizes :carrier, :tracking_url, :service, with: ->(value) { value&.to_s&.strip&.presence }

    # Numbers from the big carriers encode who they belong to; pinning the
    # detected carrier means the badge and the URL survive when the merchant
    # only pasted a number. Fills a blank only — a merchant's or a provider's
    # explicit carrier is never second-guessed, and a forwarder's name is a
    # legal value: nothing validates +carrier+ against the registry.
    before_validation :detect_carrier, if: -> { carrier.blank? && tracking_number.present? }

    scope :chronological, -> { order(:created_at, :id) }
    scope :delivered, -> { where(status: 'delivered') }
    scope :undelivered, -> { where.not(status: 'delivered') }

    # The one status with a reader beyond the scopes: arrival is what the
    # fulfillment rolls up from. The rest are read as `status`.
    #
    # @return [Boolean]
    def delivered?
      status == 'delivered'
    end

    # What changes when a merchant corrects the tracking number: to the
    # carrier a different number is a different parcel, so the journey starts
    # over and everything belonging to the old number goes with it — its
    # status, its arrival, and the carrier and link that described it.
    # Otherwise a UPS badge and a UPS page survive onto a FedEx number, and a
    # stale arrival keeps dating the returns window.
    #
    # @param attributes [Hash] the merchant's edit
    # @return [Hash] the edit, widened when the number really changed
    def correction_attributes(attributes)
      number = attributes[:tracking_number] || attributes['tracking_number']
      return attributes if number.blank? || number.to_s.squish == tracking_number

      corrected = attributes.merge(status: 'pending', delivered_at: nil)
      corrected[:carrier] = nil if corrected[:carrier].blank? && corrected['carrier'].blank?
      corrected[:tracking_url] = nil if corrected[:tracking_url].blank? && corrected['tracking_url'].blank?
      corrected
    end

    self.whitelisted_ransackable_attributes = %w[tracking_number carrier status]

    # The public page where this consignment can be followed, best answer
    # first: the link stored on the row (pasted by the merchant, or the
    # provider's tracker page), the pinned carrier's registered tracking
    # page, the delivery method's configured format, then detection from the
    # number's format.
    #
    # Distinct from the +tracking_url+ column so that clearing the column
    # means "no link I chose" rather than "no link at all" — the derived
    # answer still applies, and a merchant can always store one explicitly.
    #
    # @return [String, nil]
    def resolved_tracking_url
      return if tracking_number.blank?

      safe_tracking_url ||
        (tracking_number if pasted_link?) ||
        provider_tracking_url.presence ||
        carrier_tracking_url.presence ||
        delivery_method_tracking_url.presence ||
        detected_tracking_url
    end

    # @return [Boolean] whether the tracking value is a full link rather than a number
    def pasted_link?
      tracking_number.to_s.start_with?('https://', 'http://')
    end

    private

    # The stored link is free text a merchant or seller pasted, and it is
    # rendered as an href by every consumer of this field. Only an http(s)
    # address with a host is handed back, so a `javascript:` or `data:` value
    # is dropped rather than executed — the same guard ShippingLabel#file_url
    # applies to a provider-supplied URL.
    def safe_tracking_url
      value = tracking_url.presence
      return if value.blank?

      uri = URI.parse(value)
      value if %w[http https].include?(uri.scheme) && uri.host.present?
    rescue URI::InvalidURIError
      nil
    end

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
      tracking_service&.tracking_url if tracking_service&.valid?
    end

    def detect_carrier
      return if pasted_link?

      self.carrier = tracking_service.tracking.courier_code.to_s if tracking_service&.valid?
    end

    # Parsing a number runs the gem's whole carrier battery, and both the
    # carrier and the URL want the answer — but a corrected number is a
    # different parcel, so the cache is keyed on the number it parsed.
    def tracking_service
      return if tracking_number.blank?

      number = tracking_number.upcase
      return @tracking_service if @tracking_service_number == number

      @tracking_service_number = number
      @tracking_service = Spree.tracking_number_service.new(number)
    end
  end
end
