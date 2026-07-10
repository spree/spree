module Spree
  module Api
    module V3
      module Admin
        class ZoneSerializer < V3::BaseSerializer
          typelize name: :string,
                   description: [:string, nullable: true],
                   default_tax: :boolean

          attributes :name, :description, :default_tax,
                     created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
