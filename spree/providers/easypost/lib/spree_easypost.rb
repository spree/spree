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
  def self.ounces(weight, store)
    unit_system = store&.preferred_unit_system.presence || 'imperial'
    converted = (weight.to_f * OUNCES_PER_UNIT.fetch(unit_system.to_s, 16.0)).round(2)

    [converted, MINIMUM_OUNCES].max
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
end
