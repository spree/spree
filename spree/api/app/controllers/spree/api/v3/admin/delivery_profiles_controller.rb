module Spree
  module Api
    module V3
      module Admin
        # Fulfillment profiles — the grouping that decides how a set of
        # products ships (origins, zones, methods). Stock-location membership
        # is managed atomically through the profile: `stock_location_ids`
        # replaces the full set; an empty array means every store location.
        class DeliveryProfilesController < ResourceController
          scoped_resource :settings

          # GET /api/v3/admin/delivery_profiles/kinds
          # Registered profile kinds, so admin UIs offer extension-added
          # kinds without hardcoding the built-ins.
          def kinds
            authorize! :create, model_class

            data = Spree.delivery_profile_types.map do |profile_class|
              {
                type: profile_class.to_s,
                kind: profile_class.name.demodulize.underscore
              }
            end

            render json: { data: data }
          end

          def create
            @resource = model_class.new(assignable_params)
            authorize_resource!(@resource, :create)

            if @resource.save
              apply_default_group_locations(@resource)
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource.assign_attributes(assignable_params)

            if @resource.save
              apply_default_group_locations(@resource)
              render json: serialize_resource(@resource)
            else
              render_validation_error(@resource.errors)
            end
          end

          protected

          def model_class
            Spree::DeliveryProfile
          end

          def serializer_class
            Spree.api.admin_delivery_profile_serializer
          end

          def scope
            super.order_default
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :name, :default, :position, :kind, stock_location_ids: [])
          end

          def collection_includes
            [delivery_origin_groups: :stock_locations]
          end

          private

          def assignable_params
            attributes = permitted_params.except(:kind, :stock_location_ids)

            if @resource.nil?
              attributes[:type] = params.key?(:kind) ? resolve_kind(params[:kind]).to_s : Spree::DeliveryProfiles::Shipping.to_s
            end

            attributes
          end

          # The profile-level shorthand writes the default origin group's
          # membership — one call keeps working for single-group stores;
          # multi-group stores manage members through the nested endpoint.
          def apply_default_group_locations(profile)
            return unless params.key?(:stock_location_ids)

            locations = Array(params[:stock_location_ids]).map do |id|
              current_store.stock_locations.accessible_by(current_ability, :show).find_by_prefix_id!(id)
            end
            profile.default_origin_group&.stock_locations = locations
          end

          # The wire kind (`shipping`, `digital`) resolves against the
          # registry; an unknown kind is a client error, not a constantize.
          def resolve_kind(kind)
            Spree.delivery_profile_types.find { |klass| klass.name.demodulize.underscore == kind.to_s } ||
              raise(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
