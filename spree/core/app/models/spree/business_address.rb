module Spree
  # A seller's billing address, as a commission invoice must address it: no
  # person to name, and the company is the part that cannot be left out.
  #
  # Shares `spree_addresses` rather than being STI — the table has no `type`
  # column, and the owning association already says which kind this is.
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
