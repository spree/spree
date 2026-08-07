module Spree
  module Api
    module V3
      module Admin
        # Delivery zones with typed members (country / state / postal_code).
        # Members are managed atomically through the zone: `members` in the
        # payload replaces the full member set.
        class DeliveryZonesController < ResourceController
          scoped_resource :settings

          def create
            @resource = model_class.new(zone_params)
            authorize_resource!(@resource, :create)

            build_members(@resource) if params.key?(:members)

            if @resource.save
              render json: serialize_resource(@resource), status: :created
            else
              render_validation_error(@resource.errors)
            end
          end

          def update
            @resource.assign_attributes(zone_params)

            model_class.transaction do
              if params.key?(:members)
                @resource.members.destroy_all
                build_members(@resource)
              end

              if @resource.save
                render json: serialize_resource(@resource)
              else
                render_validation_error(@resource.errors)
                raise ActiveRecord::Rollback
              end
            end
          end

          protected

          def model_class
            Spree::DeliveryZone
          end

          def serializer_class
            Spree.api.admin_delivery_zone_serializer
          end

          def permitted_params
            params.permit(
              :name, :description, :delivery_profile_id, :delivery_origin_group_id,
              members: [:member_type, :country_iso, :state_abbr, :postal_code_prefix, :postal_code_from, :postal_code_to]
            )
          end

          def collection_includes
            [:members]
          end

          private

          # A zone always lives inside a profile; absent an explicit one it
          # joins the store default.
          def zone_params
            attributes = permitted_params.except(:members, :delivery_profile_id, :delivery_origin_group_id)
            if params.key?(:delivery_profile_id) && params[:delivery_profile_id].present?
              attributes[:delivery_profile] = current_store.delivery_profiles.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_profile_id])
            end
            if params.key?(:delivery_origin_group_id) && params[:delivery_origin_group_id].present?
              attributes[:delivery_origin_group] = current_store.delivery_origin_groups.accessible_by(current_ability, :show).find_by_prefix_id!(params[:delivery_origin_group_id])
            end
            attributes
          end

          # Members are stored as codes. A subdivision may be given by code or
          # by name, and a state member without a country has its country
          # inferred — a code alone is ambiguous ("CA" is California and
          # several other places), so an inference matching more than one
          # country is rejected rather than guessed at.
          def build_members(zone)
            Array(permitted_params[:members]).each do |member|
              attributes = member.to_h.symbolize_keys
              country_iso = attributes[:country_iso].presence&.to_s&.upcase
              state_value = attributes[:state_abbr].presence

              if state_value.present?
                country_iso ||= infer_country_iso_for_state(state_value)
                attributes[:state_abbr] = Spree::IsoData.subdivision_code(country_iso, state_value) if country_iso
              end

              attributes[:country_iso] = country_iso
              zone.members.build(attributes)
            end
          end

          # Returns nil when the code is ambiguous, which leaves the member
          # without a country for its presence validation to reject — better
          # than silently picking one of several matching countries.
          #
          # @return [String, nil] the only country whose subdivisions match, if exactly one does
          def infer_country_iso_for_state(state_value)
            matches = Spree::IsoData.countries.map(&:alpha2).select do |iso|
              Spree::IsoData.subdivision_code(iso, state_value).present?
            end

            matches.one? ? matches.first : nil
          end
        end
      end
    end
  end
end
