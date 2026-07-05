module Spree
  module Api
    module V3
      module Admin
        # Admin API serializer for {Spree::Role}. Read-only — used to populate
        # the role picker on the staff invite/edit forms. Spree core ships
        # with a single `admin` role today; richer role/permission management
        # is on the roadmap.
        class RoleSerializer < V3::BaseSerializer
          typelize name: :string

          attributes :name, created_at: :iso8601, updated_at: :iso8601
        end
      end
    end
  end
end
