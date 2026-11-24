module Spree
  module Api
    module V3
      module Admin
        # A payment method type, with its gallery listing.
        class PaymentMethodTypeSerializer < ResourceTypeDefinitionSerializer
          typelize logo_url: [:string, nullable: true, comment: 'Gallery logo: an absolute URL or a `data:` URI'],
                   docs_url: [:string, nullable: true, comment: "Absolute URL of the provider's setup guide"],
                   third_party: [:boolean, comment: 'Backed by an outside payment provider rather than handled by the store itself'],
                   installed: [:boolean, comment: 'The store has a payment method of this type already']

          attributes :logo_url, :docs_url, :third_party, :installed
        end
      end
    end
  end
end
