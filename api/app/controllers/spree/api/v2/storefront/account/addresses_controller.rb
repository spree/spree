module Spree
  module Api
    module V2
      module Storefront
        module Account
          class AddressesController < ::Spree::Api::V2::BaseController
            before_action :require_spree_current_user

            def index
              render_serialized_payload { serialize_collection(collection) }
            end

            def create
              resource = collection.new(address_params)
              if resource.save
                render_serialized_payload { serialize_resource(resource) }
              else
                render_error_payload(Spree::ServiceModule::ResultError.new(resource.errors))
              end
            end

            def update
              if resource.update(address_params)
                render_serialized_payload { serialize_resource(resource) }
              else
                render_error_payload(Spree::ServiceModule::ResultError.new(resource.errors))
              end
            end

            private

            def collection
              spree_current_user.addresses
            end

            def resource
              @resource ||= collection.find(params[:id])
            end

            def collection_serializer
              Spree::Api::Dependencies.storefront_address_serializer.constantize
            end

            def resource_serializer
              Spree::Api::Dependencies.storefront_address_serializer.constantize
            end

            def serialize_collection(collection)
              collection_serializer.new(collection).serializable_hash
            end

            def address_params
              replace_country_iso_with_id(params).require(:address).permit(permitted_address_attributes)
            end

            def replace_country_iso_with_id(params)
              iso = params.dig(:address, :country_iso)
              return params unless iso.present?

              replaced_params = params
              replaced_params[:address]['country_id'] = Spree::Country.find_by(iso: iso)&.id
              replaced_params[:address].delete(:country_iso)
              replaced_params
            end
          end
        end
      end
    end
  end
end
