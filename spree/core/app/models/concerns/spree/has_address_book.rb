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
    # Each flag has three meanings, and they are all different: true promotes
    # this address, false gives up the slot — but only when this address is
    # what currently holds it, since another entry's default is not this
    # caller's business — and nil leaves the slot alone.
    #
    # @param address_id [Integer]
    # @param billing [Boolean, nil] promote to, or release, the billing slot
    # @param shipping [Boolean, nil] promote to, or release, the shipping slot
    def assign_default_address(address_id:, billing: true, shipping: true)
      promoted = {}
      released = []

      { bill: billing, ship: shipping }.each do |kind, flag|
        column = default_address_columns[kind]

        if flag
          promoted[column] = address_id
        elsif flag == false
          released << column
        end
      end

      promote_default_columns(promoted)
      release_default_columns(released, address_id)

      reload if persisted? && (promoted.any? || released.any?)
    end

    # @param kind [Symbol] :bill or :ship
    # @return [Integer, nil] the address this owner prefills that slot with
    def default_address_id(kind)
      public_send(default_address_columns.fetch(kind))
    end

    private

    def promote_default_columns(columns)
      return if columns.empty?

      update_columns(**columns, updated_at: Time.current)
    end

    # Released in one conditional statement rather than read-then-write: a
    # request giving up a slot must not undo a promotion that landed between
    # the two. The WHERE clause is the check, so a slot already moved on is
    # simply not matched.
    def release_default_columns(columns, address_id)
      return if columns.empty?

      columns.each do |column|
        self.class.where(id: id, column => address_id).
          update_all(column => nil, updated_at: Time.current)
      end
    end
  end
end
