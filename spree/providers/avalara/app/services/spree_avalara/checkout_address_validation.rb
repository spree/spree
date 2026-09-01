module SpreeAvalara
  # Refuses to complete a checkout whose tax address Avalara cannot resolve.
  #
  # Registered on `carts.complete.validate` rather than
  # `Spree.validators.addresses`: that registry fires on every address save —
  # the customer's address book, an admin editing a record — with no checkout
  # context, so a validation belonging to one sale would block a merchant from
  # saving a legitimate address.
  class CheckoutAddressValidation
    # @param workflow [Spree::Carts::Complete]
    # @return [void]
    def call(workflow)
      cart = workflow.cart
      integration = Integration.active_for(cart&.store)
      return unless integration&.preferred_address_validation_enabled

      address = cart.tax_address
      return if address.nil?
      return unless Address::Validate::SUPPORTED_COUNTRIES.include?(address.country_code.to_s.upcase)

      result = Address::Validate.new.call(address: address, store: cart.store)
      return if result.success?
      # Advisory validation must not import Avalara's downtime into checkout.
      # Only estimate fails closed, because under-collecting tax is a liability
      # while an unverified address is a delivery risk the merchant already runs.
      return if result.error.transport?

      workflow.errors.add(:base, :avalara_address_invalid, message: result.error.summary)
      workflow.reject!
    end
  end
end
