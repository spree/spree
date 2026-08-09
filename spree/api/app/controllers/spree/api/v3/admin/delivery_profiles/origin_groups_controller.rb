module Spree
  module Api
    module V3
      module Admin
        module DeliveryProfiles
          # Origin groups of one delivery profile. `stock_location_ids`
          # replaces the group's full membership; empty means every store
          # location. The last group cannot be deleted, nor can one that
          # still holds zones or methods.
          class OriginGroupsController < ResourceController
            scoped_resource :settings

            def create
              @resource = scope.new(assignable_params)
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
            end

            def update
              @resource.assign_attributes(assignable_params)

              if @resource.save
                render json: serialize_resource(@resource)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def model_class
              Spree::DeliveryOriginGroup
            end

            def serializer_class
              Spree.api.admin_delivery_origin_group_serializer
            end

            def scope
              parent_profile.delivery_origin_groups
            end

            def permitted_params
              params.permit(:name, :position, stock_location_ids: [])
            end

            def collection_includes
              [:stock_locations]
            end

            private

            def parent_profile
              @parent_profile ||= current_store.delivery_profiles.
                accessible_by(current_ability, :show).
                find_by_prefix_id!(params[:delivery_profile_id])
            end

            def assignable_params
              attributes = permitted_params.except(:stock_location_ids)

              if params.key?(:stock_location_ids)
                attributes[:stock_locations] = Array(params[:stock_location_ids]).map do |id|
                  current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
                end
              end

              attributes
            end
          end
        end
      end
    end
  end
end
