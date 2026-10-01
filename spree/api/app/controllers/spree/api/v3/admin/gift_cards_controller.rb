module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::GiftCard`. Scoped to the current store via
        # the model's `SingleStoreResource` include — the base controller's
        # `scope` already applies `model_class.for_store(current_store)`.
        #
        # `store` and `created_by` are auto-stamped by `build_resource` in
        # `Spree::Api::V3::ResourceController`, so create requests only need
        # to include user-facing attributes (amount, currency, expires_at,
        # optional code, optional customer_id).
        class GiftCardsController < ResourceController
          scoped_resource :gift_cards

          before_action :resolve_customer, only: [:create, :update]

          protected

          def model_class
            Spree::GiftCard
          end

          def serializer_class
            Spree.api.admin_gift_card_serializer
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :code, :amount, :expires_at, :currency).tap do |attributes|
              attributes[:customer] = @customer if params.key?(:customer_id)
            end
          end

          private

          # Assigning a customer embeds their record in the response, so it is
          # a read of customers: the caller must hold that permission, and the
          # customer is resolved through their ability — never a raw id the
          # model would look up across every customer.
          def resolve_customer
            return unless params.key?(:customer_id)
            return @customer = nil if params[:customer_id].blank?

            unless holds_permission?('read_customers')
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
                message: 'Missing permission: read_customers',
                status: :forbidden,
                details: { required_permission: 'read_customers' }
              )
            end

            @customer = Spree.customer_class.
                        accessible_by(current_ability, :show).
                        find_by_prefix_id!(params[:customer_id])
          end
        end
      end
    end
  end
end
