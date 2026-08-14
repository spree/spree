require 'easypost'
require 'spree_core'
require 'spree_easypost/engine'

module SpreeEasyPost
  # Vendor branding, shared by both providers and the integration.
  PROVIDER_NAME = 'EasyPost'.freeze

  OUNCES_PER_UNIT = {
    'imperial' => 16.0,   # pounds
    'metric' => 0.03527396 # grams
  }.freeze

  # EasyPost rejects a parcel weighing zero ("must be greater than 0"), and
  # products without a weight are ordinary in Spree — so a weightless package
  # is quoted at this nominal ounce rather than failing the whole request.
  # Rates come back slightly low for such carts, which is the better failure:
  # the alternative is no delivery options at all.
  MINIMUM_OUNCES = 0.1

  # EasyPost expects parcel weight in ounces; Spree stores weight in the
  # store's unit system.
  #
  # @param weight [Numeric, nil]
  # @param store [Spree::Store, nil]
  # @return [Float]
  CM_PER_INCH = 2.54

  # EasyPost expects parcel dimensions in inches; the store's default
  # package records them in the unit its unit system implies (in/cm).
  #
  # @param value [Numeric, nil]
  # @param store [Spree::Store, nil]
  # @return [Float]
  def self.inches(value, store)
    metric = store&.preferred_unit_system.to_s == 'metric'
    inches = metric ? value.to_f / CM_PER_INCH : value.to_f

    inches.round(2)
  end

  def self.ounces(weight, store)
    unit_system = store&.preferred_unit_system.presence || 'imperial'
    converted = (weight.to_f * OUNCES_PER_UNIT.fetch(unit_system.to_s, 16.0)).round(2)

    [converted, MINIMUM_OUNCES].max
  end

  # EasyPost parcel payload for a package: weight always, dimensions when
  # the store configured a default package — carriers bill dimensional
  # weight above size thresholds, so a weight-only parcel under-quotes
  # bulky-but-light shipments.
  #
  # @param package [Spree::Stock::Package]
  # @param store [Spree::Store, nil]
  # @return [Hash]
  def self.parcel_params(package, store)
    params = { weight: ounces(package.weight, store) }

    dimensions = package.dimensions
    return params if dimensions.nil?

    params.merge(
      length: inches(dimensions[:length], store),
      width: inches(dimensions[:width], store),
      height: inches(dimensions[:height], store)
    )
  end

  # EasyPost address payload from a Spree address or stock location.
  #
  # `name`/`company` look optional — rating succeeds without them — but
  # buying a label fails with "address.name or address.company required",
  # so both are always sent when the record has them.
  #
  # @param source [Spree::Address, Spree::StockLocation]
  # @return [Hash]
  def self.address_params(source)
    {
      name: address_name(source),
      company: source.try(:company),
      street1: source.address1,
      street2: source.address2,
      city: source.city,
      state: source.respond_to?(:state_abbr) ? source.state_abbr : source.state&.abbr,
      zip: source.zipcode,
      country: source.country&.iso,
      phone: source.phone
    }.compact_blank
  end

  # Addresses carry a person's name; stock locations carry the location's.
  def self.address_name(source)
    return source.full_name if source.respond_to?(:full_name)

    source.try(:name)
  end

  # Customs payload for an international shipment. Nil for domestic ones —
  # EasyPost rejects a customs form on a domestic label, and every carrier
  # treats "no customs_info" as the domestic case.
  #
  # Classification (HS code, country of origin) is sent per item when the
  # merchant recorded it. It is deliberately not required: carriers differ on
  # what they demand, and a rejected label carries the carrier's own message,
  # which is more actionable than a guess made here.
  #
  # @param package [Spree::Stock::Package]
  # @param origin [Spree::StockLocation, nil] where the parcel ships from
  # @param destination [Spree::Address, nil] where it is going
  # @param integration [SpreeEasyPost::Integration, nil] customs signer/contents preferences
  # @return [Hash, nil] nil when the shipment is domestic or undeterminable
  def self.customs_info_params(package, origin, destination, integration = nil)
    return unless international?(origin, destination)

    items = customs_items_params(package)
    return if items.empty?

    {
      contents_type: integration&.preferred_customs_contents_type.presence || 'merchandise',
      restriction_type: 'none',
      eel_pfc: 'NOEEI 30.37(a)',
      customs_certify: true,
      customs_signer: integration&.preferred_customs_signer.presence,
      customs_items: items
    }.compact_blank
  end

  # One customs item per package line. Quantity, value and weight always;
  # classification only when present.
  #
  # @param package [Spree::Stock::Package]
  # @return [Array<Hash>]
  def self.customs_items_params(package)
    store = package.owner&.store

    package.contents.filter_map do |item|
      variant = item.variant
      next if variant.nil?

      {
        description: variant.customs_description_for_declaration,
        quantity: item.quantity,
        value: (item.price.to_f * item.quantity).round(2),
        weight: ounces(item.weight, store),
        origin_country: variant.country_of_origin.presence,
        hs_tariff_number: variant.hs_code.presence,
        currency: package.owner&.currency
      }.compact_blank
    end
  end

  # A shipment crosses a customs border when its origin and destination
  # countries differ. Unknown countries mean domestic — never attach a
  # customs form on a guess.
  def self.international?(origin, destination)
    origin_iso = origin&.country&.iso
    destination_iso = destination&.country&.iso
    return false if origin_iso.blank? || destination_iso.blank?

    origin_iso != destination_iso
  end

  # EndShipper payload — the party legally responsible for the shipment,
  # required when buying labels on EasyPost's own carrier accounts (USPS
  # refuses the purchase without one). Unlike a plain address, EasyPost
  # makes every field mandatory here including phone and email, so the
  # store's contact details fill in what the stock location does not carry.
  #
  # @param stock_location [Spree::StockLocation, nil]
  # @param store [Spree::Store, nil]
  # @return [Hash, nil] nil when the mandatory fields cannot be assembled
  def self.end_shipper_params(stock_location, store)
    return if stock_location.nil?

    params = address_params(stock_location)
    params[:phone] = stock_location.phone.presence || store&.contact_phone.presence
    params[:email] = store&.mail_from_address.presence || store&.customer_support_email.presence

    mandatory = params.values_at(:street1, :city, :state, :zip, :country, :phone, :email)
    mandatory << (params[:name].presence || params[:company].presence)
    return if mandatory.any?(&:blank?)

    params.compact_blank
  end
end
