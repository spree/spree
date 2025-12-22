module Spree
  module Admin
    module Orders
      class ContactInformationController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order

        def edit; end

        def update
          if Spree::Orders::UpdateContactInformation.call(order: @order, order_params: order_params).success?
            unless @order.completed?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              result = Spree.checkout_advance_service.call(order: @order, state: max_state)

              unless result.success?
                flash[:error] = result.error.value.full_messages.to_sentence
                @order.ensure_updated_shipments
                return redirect_to spree.edit_admin_order_path(@order)
              end
            end

            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:contact_information))
            redirect_to spree.edit_admin_order_path(@order)
          else
            render :edit
          end
        end

        private

        def order_params
          params.require(:order).permit(:email)
        end
      end
    end
  end
end
