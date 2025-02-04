module Spree
  module Admin
    class PaymentsController < Spree::Admin::ResourceController
      belongs_to 'spree/order', find_by: :number

      before_action :load_data
      new.before :proceed_order_state

      def new
        payment_method = params[:payment_method_id] ? @payment_methods.find { |pm| pm.id.to_s == params[:payment_method_id].to_s } : @payment_methods.first

        @payment = @order.payments.build(
          amount: @order.total_minus_store_credits - @order.payment_total,
          payment_method: payment_method
        )

        if payment_method.try(:source_required?)
          source_class = (payment_method.try(:payment_source_class) || Spree::CreditCard)
          @payment.source = source_class&.new
        end
      end

      def create
        invoke_callbacks(:create, :before)

        @order.transaction do
          @object.attributes = permitted_resource_params
          @object.build_source
          @object.save!

          if @order.billing_address.nil?
            @order.clone_shipping_address
            @order.save!
          end
        end

        @object.process!

        # Transition order as far as it will go.
        while @order.next; end
        # If "@order.next" didn't trigger payment processing already (e.g. if the order was
        # already complete) then trigger it manually now

        invoke_callbacks(:create, :after)

        redirect_to location_after_save
      rescue Spree::Core::GatewayError => e
        @object.failure if defined?(@object) && @object.persisted?
        invoke_callbacks(:create, :fails)

        flash[:error] = e.message.to_s
        render :new, status: :unprocessable_entity
      rescue ActiveRecord::RecordInvalid => _e
        @object.failure if defined?(@object) && @object.persisted?
        invoke_callbacks(:create, :fails)

        render :new, status: :unprocessable_entity
      end

      def capture
        if @payment.capture!
          flash[:success] = Spree.t(:payment_updated)
          # move order to next state if possible
          while @order.next; end
        else
          flash[:error] = @payment.errors.full_messages.to_sentence
        end
        redirect_to location_after_save
      rescue Spree::Core::GatewayError => ge
        flash[:error] = ge.message.to_s
        redirect_to location_after_save
      end

      def void
        if @payment.void_transaction!
          flash[:success] = Spree.t(:payment_updated)
        else
          flash[:error] = Spree.t(:cannot_perform_operation)
        end
        redirect_to location_after_save
      rescue Spree::Core::GatewayError => ge
        flash[:error] = ge.message.to_s
        redirect_to location_after_save
      end

      private

      def proceed_order_state
        # Move order to payment state in order to capture tax generated on shipments
        if @order.can_go_to_state?('payment')
          @order.next
        end
      end

      def build_resource
        # This method is overridden because we don't want order to have invalid payment since we are doing `order.next` in the `new` action
        model_class.new(order: parent)
      end

      def model_class
        Spree::Payment
      end

      def permitted_resource_params
        params.require(:payment).permit(permitted_payment_attributes)
      end

      def collection_url
        spree.edit_admin_order_path(@order)
      end

      def location_after_save
        collection_url
      end

      def load_data
        @payment_methods = @order.collect_backend_payment_methods
      end
    end
  end
end
