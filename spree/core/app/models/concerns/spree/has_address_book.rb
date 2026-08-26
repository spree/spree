module Spree
  # Anything that keeps an address book: a customer, a company node, and
  # whatever comes next.
  #
  # Owners already differ in what they call their default slots — a customer
  # has +bill_address_id+ / +ship_address_id+, a company node
  # +default_bill_address_id+ / +default_ship_address_id+ — so the columns are
  # declared once here and every caller asks the owner instead of knowing
  # which of them it is holding.
  #
  #   class Spree::Company < Spree.base_class
  #     has_address_book bill: :default_bill_address_id, ship: :default_ship_address_id
  #   end
  module HasAddressBook
    extend ActiveSupport::Concern

    class_methods do
      # @param bill [Symbol] column holding the default billing address id
      # @param ship [Symbol] column holding the default shipping address id
      def has_address_book(bill:, ship:)
        class_attribute :default_address_columns, instance_writer: false, default: { bill: bill, ship: ship }
      end
    end

    # Points this owner's default slots at an address.
    #
    # Writes the columns directly: callers have already established that the
    # address is this owner's, so the ownership validation this skips cannot
    # fail, and skipping it avoids re-running a whole validation set to move
    # one foreign key.
    #
    # @param address_id [Integer]
    # @param billing [Boolean] promote to the default billing slot
    # @param shipping [Boolean] promote to the default shipping slot
    def assign_default_address(address_id:, billing: true, shipping: true)
      attributes = {
        default_address_columns[:bill] => (address_id if billing),
        default_address_columns[:ship] => (address_id if shipping)
      }.compact_blank

      return if attributes.blank?

      update_columns(**attributes, updated_at: Time.current)
    end

    # @param kind [Symbol] :bill or :ship
    # @return [Integer, nil] the address this owner prefills that slot with
    def default_address_id(kind)
      public_send(default_address_columns.fetch(kind))
    end
  end
end
