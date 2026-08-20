module Spree
  # An address belonging to a business rather than a person — a seller's
  # billing address, as a commission invoice must address it.
  #
  # Shares `spree_addresses` with its parent rather than being STI: the table
  # has no `type` column, and adding one to reach every order, customer and
  # company row would be a heavy migration to record what the owning
  # association already says.
  #
  # What differs is who the address names. There is no person to ask for, and
  # the company is the part that cannot be left out.
  class BusinessAddress < Spree::Address
    def require_name?
      false
    end

    def require_company?
      !quick_checkout
    end

    def show_company_address_field?
      true
    end
  end
end
