module SpreeAvalara
  # An address or stock location as AvaTax's AddressLocationInfo. Both sides of
  # a supply present the same way, and both records answer the same readers.
  class AddressPresenter
    # @param source [Spree::Address, Spree::StockLocation, nil]
    def initialize(source)
      @source = source
    end

    # @return [Hash, nil] nil when there is no address to describe
    def call
      return if source.nil?

      {
        line1: source.address1,
        line2: source.address2,
        city: source.city,
        region: source.state_code,
        country: source.country_code,
        postalCode: source.zipcode
      }.compact_blank
    end

    private

    attr_reader :source
  end
end
