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

            # POST /api/v3/admin/customers/:customer_id/store_credits
            def create
              @resource = @parent.store_credits.new(create_attrs)
              @resource.created_by = try_spree_current_user
              @resource.store ||= current_store
              @resource.category ||= Spree::StoreCreditCategory.first
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

              if @resource.amount_used.positive? && update_attrs.key?(:amount)
                render_error(
                  code: 'store_credit_in_use',
                  message: 'Cannot change amount on a store credit that has already been used',
                  status: :unprocessable_content
                )
                return
              end

              if @resource.update(update_attrs)
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

            def parent_association
              :store_credits
            end

            def model_class
              Spree::StoreCredit
            end

            def serializer_class
              Spree.api.admin_store_credit_serializer
            end

            private

            def create_attrs
              params.permit(:amount, :currency, :category_id, :memo).to_h
            end

            def update_attrs
              params.permit(:memo, :category_id, :amount).to_h
            end
          end
        end
      end
    end
  end
end
