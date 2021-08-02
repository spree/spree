module Spree
  module Api
    module V2
      module Storefront
        module Account
          class CreditCardsController < ::Spree::Api::V2::ResourceController
            before_action :require_spree_current_user

            def index
              render_serialized_payload { serialize_collection(collection) }
            end

            def show
              render_serialized_payload { serialize_resource(resource) }
            end

            def destroy
              spree_authorize! :destroy, resource, resource

              destroy_service.call(card: resource)
            end

            private

            def resource
              if params[:id].eql?('default')
                scope.default.first!
              else
                scope.find(params[:id])
              end
            end

            def collection
              collection_finder.new(scope: scope, params: params).execute
            end

            def serialize_collection(collection)
              collection_serializer.new(collection).serializable_hash
            end

            def scope
              super.where(user: spree_current_user, payment_method: current_store.payment_methods.available_on_front_end)
            end

            def collection_serializer
              Spree::Api::Dependencies.storefront_credit_card_serializer.constantize
            end

            def collection_finder
              Spree::Api::Dependencies.storefront_credit_card_finder.constantize
            end

            def resource_serializer
              Spree::Api::Dependencies.storefront_credit_card_serializer.constantize
            end

            def destroy_service
              Spree::Api::Dependencies.storefront_credit_cards_destroy_service.constantize
            end
          end
        end
      end
    end
  end
end
