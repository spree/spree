module Spree
  # The address of a business entity — a seller's billing address, a company
  # location's branch. No person to name, and the company is the part that
  # cannot be left out.
  #
  # STI rather than a class picked by the owning association, so the rules
  # travel with the row: copied onto a base-typed association such as a cart's
  # bill_address, it still loads and validates as a business address.
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
