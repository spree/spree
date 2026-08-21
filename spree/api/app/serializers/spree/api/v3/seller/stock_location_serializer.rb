module Spree
  module Api
    module V3
      module Seller
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
