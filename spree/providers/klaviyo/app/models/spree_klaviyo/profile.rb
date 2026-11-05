module SpreeKlaviyo
  # One Klaviyo profile, as a `POST /api/profile-import` body.
  #
  # A customer's profile carries an external_id, so Klaviyo keeps one profile
  # when the customer changes their email. A guest is identified by email alone.
  class Profile
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :email, :string
    attribute :first_name, :string
    attribute :last_name, :string
    attribute :external_id, :string
    attr_accessor :location

    # @param customer [Spree::Customer]
    # @param use_database_ids [Boolean] the integration's use_database_ids_as_external_ids
    # @return [SpreeKlaviyo::Profile]
    def self.from_customer(customer, use_database_ids: false)
      new(
        email: customer.email,
        first_name: customer.first_name,
        last_name: customer.last_name,
        external_id: external_id_for(customer, use_database_ids),
        location: location_from(customer.bill_address)
      )
    end

    # @param order [Spree::Order, Spree::Cart, Spree::OrderGroup]
    # @param use_database_ids [Boolean] the integration's use_database_ids_as_external_ids
    # @return [SpreeKlaviyo::Profile]
    def self.from_order(order, use_database_ids: false)
      address = order.bill_address
      customer = order.customer

      new(
        email: order.email,
        first_name: address&.first_name.presence || customer&.first_name,
        last_name: address&.last_name.presence || customer&.last_name,
        external_id: customer && external_id_for(customer, use_database_ids),
        location: location_from(address)
      )
    end

    # The prefixed id by default; the database id is what 1.x sent.
    def self.external_id_for(customer, use_database_ids)
      use_database_ids ? customer.id.to_s : customer.prefixed_id
    end

    def self.location_from(address)
      return if address.nil?

      {
        address1: address.address1,
        address2: address.address2,
        city: address.city,
        region: address.state_name_text,
        zip: address.postal_code,
        country: address.country_code
      }.compact_blank.presence
    end

    private_class_method :external_id_for, :location_from

    # @return [Hash]
    def to_body
      {
        data: {
          type: 'profile',
          attributes: {
            email: email,
            first_name: first_name,
            last_name: last_name,
            external_id: external_id,
            location: location
          }.compact
        }
      }
    end
  end
end
