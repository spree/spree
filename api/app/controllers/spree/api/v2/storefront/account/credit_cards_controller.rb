module Spree
  module Api
    module V2
      module Storefront
        module Account
          class CreditCardsController < ::Spree::Api::V2::BaseController
            def index
              render_serialized_payload { serialize_resource(resource) }
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
                credit_card_serializer: Spree::V2::Storefront::Account::CreditCardSerializer
              }
            end

            def serialize_resource(resource)
              dependencies[:credit_card_serializer].new(resource).serializable_hash
            end

            def scope
              Spree.user_class.accessible_by(current_ability, :read).find(params[:user_id])
            end
          end
        end
      end
    end
  end
end
