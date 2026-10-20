module Spree
  module Api
    module V3
      module Seller
        # A country as the seller panel's address forms need it. The panel
        # names countries with Intl.DisplayNames in the seller's own language,
        # so the Seller API sends the ISO code alone.
        class CountrySerializer < V3::CountrySerializer
          _attributes.delete(:name)
          _attributes.delete(:market)

          many :states,
               resource: proc { Spree.api.seller_state_serializer },
               if: proc { params[:expand]&.include?('states') }
        end
      end
    end
  end
end
