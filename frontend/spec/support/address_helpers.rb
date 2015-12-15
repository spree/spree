module SpreeSpec
  # @api private
  module AddressHelper
    # Fill in address form
    #
    # @param prefix [String]
    # @param address [Spree::Address]
    #
    # @return [undefined]
    def fill_in_address_form(prefix, address)
      fill_in "#{prefix}_firstname", with: address.firstname
      fill_in "#{prefix}_lastname",  with: address.lastname
      fill_in "#{prefix}_address1",  with: address.address1
      fill_in "#{prefix}_city",      with: address.city
      select country.name,           from: "#{prefix}_country_id"
      select state.name,             from: "#{prefix}_state_id"
      fill_in "#{prefix}_zipcode",   with: address.zipcode
      fill_in "#{prefix}_phone",     with: address.phone
    end
  end # AddressHelper
end # SpreeSpec
