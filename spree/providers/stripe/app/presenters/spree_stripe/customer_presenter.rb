module SpreeStripe
  class CustomerPresenter
    def initialize(address: nil, email: nil, name: nil)
      @email = email
      @name = name
      @address = address
    end

    # @return [Hash]
    def call
      hash = {}
      hash[:address] = address_payload if address.present?
      hash[:email] = email if email.present?
      hash[:name] = name if name.present?
      hash
    end

    private

    attr_reader :email, :name, :address

    # ISO codes, matching the intent's shipping payload — Stripe expects
    # ISO 3166-1 alpha-2 for country, and full names degrade Stripe-side
    # location resolution (tax, risk rules).
    def address_payload
      {
        city: address.city,
        line1: address.address1,
        line2: address.address2,
        postal_code: address.zipcode,
        country: address.country_iso,
        state: address.state_abbr.presence || address.state_name_text
      }
    end
  end
end
