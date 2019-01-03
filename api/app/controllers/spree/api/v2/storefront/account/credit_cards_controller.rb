module Spree
  module Api
    module V2
      module Storefront
        module Account
          class CreditCardsController < ::Spree::Api::V2::BaseController
            def index
              render_serialized_payload { serialize_collection(resource) }
            end

            def show
              render_serialized_payload { serialize_resource(resource) }
            end

            private

            def resource
              dependencies[:resource_finder].new.execute(scope: scope, params: params)
            end

            def dependencies
              {
                resource_finder: Spree::CreditCards::Find,
                collection_serializer: Spree::V2::Storefront::Account::CreditCardSerializer,
                resource_serializer: Spree::V2::Storefront::Account::CreditCardSerializer
              }
            end

            def serialize_collection(collection)
              dependencies[:collection_serializer].new(
                collection,
                include: resource_includes,
                fields: sparse_fields
              ).serializable_hash
            end

            def serialize_resource(resource)
              dependencies[:resource_serializer].new(
                resource,
                include: resource_includes,
                fields: sparse_fields
              ).serializable_hash
            end

            def scope
              raise CanCan::AccessDenied if spree_current_user.nil?

              spree_current_user.credit_cards.accessible_by(current_ability, :read)
            end
          end
        end
      end
    end
  end
end
