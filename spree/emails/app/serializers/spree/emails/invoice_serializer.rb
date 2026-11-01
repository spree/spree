module Spree
  module Emails
    # An invoice as its email reads it. The file travels as an attachment, so
    # the API download path is left out.
    class InvoiceSerializer < Spree::Api::V3::InvoiceSerializer
      _attributes.delete(:download_url)

      without_display_money
    end
  end
end
