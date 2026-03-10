module Spree
  module Api
    module V3
      module Admin
        class StoreController < Admin::BaseController
          # GET /api/v3/admin/store
          def show
            authorize! :show, current_store
            render json: serialize_store
          end

          # PATCH /api/v3/admin/store
          def update
            authorize! :update, current_store

            if current_store.update(permitted_params)
              render json: serialize_store
            else
              render_validation_error(current_store.errors)
            end
          end

          private

          def serialize_store
            serializer_class.new(current_store, params: serializer_params).to_h
          end

          def serializer_class
            Spree.api.admin_store_serializer
          end

          def permitted_params
            params.permit(Spree::PermittedAttributes.store_attributes)
          end
        end
      end
    end
  end
end
