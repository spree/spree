module Spree
  module Api
    module V2
      module Storefront
        module Account
          class CreditCardsController < ::Spree::Api::V2::BaseController
            def index
              render_serialized_payload serialize_resource(resource)
            end

            def show
              render_serialized_payload serialize_resource(resource)
            end

            private

            def resource
              return scope.credit_cards.default if params[:id].eql?('default')
              return scope.credit_cards.where(payment_method_id: params[:filter]['payment_method_id']) if params[:filter].present?

              scope.credit_cards
            end

            def dependencies
              {
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
