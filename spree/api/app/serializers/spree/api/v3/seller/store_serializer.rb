module Spree
  module Api
    module V3
      module Seller
        # What a seller may know about the marketplace they sell on: its name,
        # and the settings that shape what the panel lets them do.
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string

          attributes :name

          preference_attributes Spree::Store, :seller_digital_assets_enabled, :seller_digital_asset_content_types,
                                              :review_seller_digital_asset_changes
        end
      end
    end
  end
end
