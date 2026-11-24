module Spree
  module Api
    module V3
      module Admin
        # The permission catalog discovery endpoint — the vocabulary the role
        # editor and the API-key scope picker render. It is vocabulary, not
        # data, so any authenticated admin credential may read it (same class
        # of exemption as `/tags`).
        #
        # Staff keys only. Both surfaces this feeds build something owned by
        # the store — a store role, a secret key — and a key another audience
        # holds (a seller's own profile or books) would render as an option
        # that fails validation the moment it is picked.
        class PermissionsController < Admin::BaseController
          skip_scope_check!

          # GET /api/v3/admin/permissions
          def index
            entries = paginate_whole(Spree.permissions.entries)

            render json: {
              data: entries.map { |entry| serializer_class.new(entry).to_h },
              meta: collection_meta(entries)
            }
          end

          private

          def serializer_class
            Spree.api.admin_permission_serializer
          end
        end
      end
    end
  end
end
