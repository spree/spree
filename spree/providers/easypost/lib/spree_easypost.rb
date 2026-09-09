require 'easypost'
require 'spree_core'
require 'spree_easypost/engine'

module SpreeEasyPost
  # Vendor branding, shared by both providers and the integration.
  PROVIDER_NAME = 'EasyPost'.freeze

  # EasyPost rejects a parcel weighing zero ("must be greater than 0"), and
  # products without a weight are ordinary in Spree — so a weightless package
  # is quoted at this nominal ounce rather than failing the whole request.
  # Rates come back slightly low for such carts, which is the better failure:
  # the alternative is no delivery options at all.
  MINIMUM_OUNCES = 0.1

  # EasyPost expects parcel dimensions in inches. A package reports its
  # dimensions in the unit the store's system implies, so the conversion is
  # from there — through the one conversion table Spree has, rather than a
  # second copy of the same constants.
  #
  # @param value [Numeric, nil]
  # @param store [Spree::Store, nil]
  # @return [Float]
  def self.inches(value, store)
    from = Spree::Variant.store_dimensions_unit(store)

    Spree::Measurement.convert_length(value, from: from, to: 'in').to_f.round(2)
  end

  # EasyPost expects parcel weight in ounces. A package reports its weight in
  # the store's weight unit, which is a separate setting from its unit
  # system — a metric store may still weigh in pounds.
  #
  # @param weight [Numeric, nil]
  # @param store [Spree::Store, nil]
  # @return [Float]
  def self.ounces(weight, store)
    from = store&.preferred_weight_unit.presence || Spree::Measurement::DEFAULT_WEIGHT_UNIT
    converted = Spree::Measurement.convert_weight(weight, from: from, to: 'oz').to_f.round(2)

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

  # US export filings are waived below this declared value (NOEEI 30.37(a));
  # above it a shipment needs its own filing number, which only the merchant
  # can supply, so no exemption is claimed on its behalf.
  EEI_EXEMPTION_LIMIT_USD = 2_500

  # Customs payload for an international shipment. Nil for domestic ones —
  # EasyPost rejects a customs form on a domestic label, and every carrier
  # treats "no customs_info" as the domestic case.
  #
  # Classification (HS code, country of origin) is sent per item when the
  # merchant recorded it. It is deliberately not required: carriers differ on
  # what they demand, and a rejected label carries the carrier's own message,
  # which is more actionable than a guess made here.
  #
  # The declaration is only certified when the integration names a signer:
  # EasyPost requires one whenever `customs_certify` is set, so certifying
  # without it would fail every international quote for an integration that
  # never configured a signer — the common case.
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

    signer = integration&.preferred_customs_signer.presence
    params = {
      contents_type: integration&.preferred_customs_contents_type.presence || 'merchandise',
      restriction_type: 'none',
      eel_pfc: eel_pfc_for(items, origin),
      customs_items: items
    }
    params[:customs_certify] = true if signer
    params[:customs_signer] = signer
    params.compact_blank
  end

  # The full shipment-create payload, shared by quoting and label purchase so
  # the two can never diverge. Whatever is set here at quote time is what a
  # label bought against that quote carries — including the customs form and
  # the duty terms, which are shipment properties EasyPost fixes at creation
  # and does not accept on the buy call.
  #
  # @param package [Spree::Stock::Package]
  # @param origin [Spree::StockLocation, nil]
  # @param destination [Spree::Address, nil]
  # @param integration [SpreeEasyPost::Integration, nil]
  # @param store [Spree::Store, nil]
  # @return [Hash]
  def self.shipment_params(package, origin, destination, integration, store)
    params = {
      from_address: address_params(origin),
      to_address: address_params(destination),
      parcel: parcel_params(package, store)
    }

    customs_info = customs_info_params(package, origin, destination, integration)
    return params if customs_info.nil?

    params[:customs_info] = customs_info
    incoterm = integration&.preferred_incoterm.presence
    params[:options] = { incoterm: incoterm } if incoterm
    params
  end

  # The US export exemption, claimed only where it actually applies: a
  # US-origin shipment declared in US dollars under the filing threshold.
  # Anything else — a foreign origin, a non-dollar declaration, a value over
  # the limit — is left for the carrier to require rather than mis-declared
  # here. The threshold is a dollar figure, so a declaration in another
  # currency cannot be compared against it without a conversion this code
  # deliberately does not attempt.
  #
  # @param items [Array<Hash>] customs items with :value and :currency
  # @param origin [Spree::StockLocation, nil]
  # @return [String, nil]
  def self.eel_pfc_for(items, origin)
    return unless origin&.country_code == 'US'
    return unless items.all? { |item| item[:currency].to_s.upcase == 'USD' }

    declared_value = items.sum { |item| item[:value].to_f }
    'NOEEI 30.37(a)' if declared_value < EEI_EXEMPTION_LIMIT_USD
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
    origin_code = origin&.country_code
    destination_code = destination&.country_code
    return false if origin_code.blank? || destination_code.blank?

    origin_code != destination_code
  end

  # EndShipper payload — the party legally responsible for the shipment,
  # required when buying labels on EasyPost's own carrier accounts (USPS
  # refuses the purchase without one). Whatever the warehouse and store can
  # supply is sent as-is: which fields EasyPost demands is its rule, and it
  # answers a payload it cannot accept by naming the field, which is more
  # use to a merchant than a list maintained here that would drift out of
  # step the first time that rule changed.
  #
  # @param stock_location [Spree::StockLocation, nil]
  # @param store [Spree::Store, nil]
  # @return [Hash, nil] nil only when there is no location to describe
  def self.end_shipper_params(stock_location, store)
    return if stock_location.nil?

    address_params(stock_location).merge(
      phone: stock_location.phone.presence || store&.contact_phone.presence,
      email: store&.mail_from_address.presence || store&.customer_support_email.presence
    ).compact_blank
  end
end
