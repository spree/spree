module Spree
  module Api
    module V3
      module Vendor
        # Anchor for the marketplace seller panel.
        #
        # Deliberately not a subclass of the admin anchor: the admin branch
        # resolves everything through `current_store`, and inheriting those
        # lookups is precisely how a seller would come to read the whole
        # store. Concerns and workflows are shared; controllers are not.
        #
        # Mirrors Vendor::ResourceController — they anchor parallel inheritance
        # branches, so a concern added to one must be added to the other.
        class BaseController < Spree::Api::V3::BaseController
          include Spree::Api::V3::Vendor::VendorContext
          include Spree::Api::V3::VendorAuthentication

          before_action :authenticate_vendor!

          include Spree::Api::V3::ScopedAuthorization
        end
      end
    end
  end
end
