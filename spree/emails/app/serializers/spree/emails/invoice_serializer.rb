module Spree
  module Emails
    # An invoice as its email reads it. The file travels as an attachment, so
    # the API download path is left out.
    class InvoiceSerializer < Spree::Api::V3::InvoiceSerializer
      _attributes.delete(:download_url)

      without_display_money

      # An email always shows the total; only the storefront hides prices.
      typelize total: [:string, nullable: false]
    end
  end
end
