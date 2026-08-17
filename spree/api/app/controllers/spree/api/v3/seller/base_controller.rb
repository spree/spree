module Spree
  module Api
    module V3
      module Seller
        # Anchor for the marketplace seller panel.
        #
        # Deliberately not a subclass of the admin anchor: the admin branch
        # resolves everything through `current_store`, and inheriting those
        # lookups is precisely how a seller would come to read the whole
        # store. Concerns and workflows are shared; controllers are not.
        #
        # Mirrors Seller::ResourceController — they anchor parallel inheritance
        # branches, so a concern added to one must be added to the other.
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::Seller::SellerContext
          include Spree::Api::V3::SellerAuthentication

          before_action :authenticate_seller!

          include Spree::Api::V3::ScopedAuthorization
        end
      end
    end
  end
end
