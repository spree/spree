module Spree
  module Api
    module V3
      module Seller
        # A seller's own stock location, as they manage it in the panel.
        #
        # Extends the store serializer rather than the admin one: the fields
        # an operator sees that a seller does not need are the ones about
        # running the marketplace's own inventory (`admin_name`,
        # `propagate_all_variants`, `backorderable_default`). What a seller
        # needs is the address, whether it is live, and whether it is the one
        # their returns go to.
        class StockLocationSerializer < V3::StockLocationSerializer
          typelize address2: [:string, nullable: true], state_name: [:string, nullable: true],
                   phone: [:string, nullable: true], company: [:string, nullable: true],
                   active: :boolean, default: :boolean, kind: :string

          attributes :address2, :state_name, :phone, :company, :active, :default, :kind,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
