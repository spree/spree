module Spree
  module Api
    module V3
      module Admin
        module Customers
          class StoreCreditsController < BaseController
            # Store credits gate on their own scope rather than the parent's
            # `:customers`, so a store-credit integration key doesn't need
            # broad customer access.
            scoped_resource :store_credits

            request_params :customer_store_credit do
              decimal :amount, required: :create, example: '50.00'
              currency :currency, required: :create, only: :create, example: 'USD'
              string :memo
            end

            # POST /api/v3/admin/customers/:customer_id/store_credits
            def create
              @resource = @parent.store_credits.new(store_credit_attributes)
              @resource.created_by = try_spree_current_user
              @resource.store ||= current_store
              authorize_resource!(@resource, :create)

              if @resource.save
                render json: serialize_resource(@resource), status: :created
              else
                render_validation_error(@resource.errors)
              end
            end

            # PATCH /api/v3/admin/customers/:customer_id/store_credits/:id
            def update
              authorize_resource!(@resource)

              if @resource.amount_used.positive? && store_credit_attributes.key?(:amount)
                render_error(
                  code: 'store_credit_in_use',
                  message: 'Cannot change amount on a store credit that has already been used',
                  status: :unprocessable_content
                )
                return
              end

              if @resource.update(store_credit_attributes)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            # DELETE /api/v3/admin/customers/:customer_id/store_credits/:id
            def destroy
              authorize_resource!(@resource)

              if @resource.amount_used.positive?
                render_error(
                  code: 'store_credit_in_use',
                  message: 'Cannot delete a store credit that has already been used',
                  status: :unprocessable_content
                )
                return
              end

              @resource.destroy
              head :no_content
            end

            protected

            # Customers are global; store credits belong to a store, so the
            # nested collection is bound to the current store.
            def scope
              @parent.store_credits.for_store(current_store)
            end

            def model_class
              Spree::StoreCredit
            end

            def serializer_class
              Spree.api.admin_store_credit_serializer
            end

            private

            def store_credit_attributes
              params.permit(*declared_permitted_attributes).to_h
            end
          end
        end
      end
    end
  end
end
