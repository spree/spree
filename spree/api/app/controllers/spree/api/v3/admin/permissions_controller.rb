module Spree
  module Api
    module V3
      module Admin
        # The permission catalog discovery endpoint — the vocabulary the role
        # editor and the API-key scope picker render. It is vocabulary, not
        # data, so any authenticated admin credential may read it (same class
        # of exemption as `/tags`).
        class PermissionsController < Admin::BaseController
          skip_scope_check!

          # GET /api/v3/admin/permissions
          def index
            entries = Spree.permissions.entries

            render json: {
              data: entries.map { |entry| Spree.api.admin_permission_serializer.new(entry).to_h },
              meta: { count: entries.size }
            }
          end
        end
      end
    end
  end
end
