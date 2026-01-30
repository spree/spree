module Spree
  class AddressesController < Spree::StoreController
    helper Spree::AddressesHelper
    before_action :require_user
    before_action :load_and_authorize_address, except: [:index]

    def create
      order_token = params[:order_token]
      @order = current_store.orders.incomplete.not_canceled.find_by(token: order_token) if order_token.present?
      result = create_service.call(
        user: try_spree_current_user,
        address_params: address_params,
        default_billing: params[:default_billing].to_b,
        default_shipping: params[:default_shipping].to_b,
        order: @order
      )
      @address = result.value

      if result.success?
        if @order.present?
          respond_to do |format|
            format.html { redirect_to spree.checkout_state_path(order_token, 'address') }
            format.turbo_stream do
              render turbo_stream: turbo_stream.update('checkout_content', partial: 'spree/checkout/address', locals: { order: @order })
            end
          end
        else
          redirect_to spree.account_addresses_path, notice: Spree.t('address_book.successfully_created')
        end
      elsif params[:from_modal].present?
        render turbo_stream: turbo_stream.update(:new_address_modal, partial: 'spree/account/addresses/new_address_modal', locals: { address: @address }), status: :unprocessable_entity
      else
        render action: 'new', status: :unprocessable_entity
      end
    end

    def edit
      store_location(request.env['HTTP_REFERER'])
    end

    def new
      @address = Spree::Address.new(country: current_store.default_country, user: try_spree_current_user)
    end

    def update
      @order = if params[:checkout].present?
                 current_store.orders.incomplete.not_canceled.find_by(token: params[:checkout])
               else
                 try_spree_current_user.orders.incomplete.not_canceled.where(ship_address_id: @address.id).
                   or(try_spree_current_user.orders.incomplete.not_canceled.where(bill_address_id: @address.id)).take
               end
      result = update_service.call(
        address: @address,
        address_params: address_params,
        default_billing: params[:default_billing].to_b,
        default_shipping: params[:default_shipping].to_b,
        order: @order,
        address_changes_except: address_changes_except
      )
      @address = result.value

      if result.success?
        flash[:notice] = Spree.t('address_book.successfully_updated') unless turbo_frame_request?

        if params[:checkout].present?
          respond_to do |format|
            format.turbo_stream do
              render turbo_stream: turbo_stream.update('checkout_content', partial: 'spree/checkout/address', locals: { order: @order })
            end
            format.html { redirect_to spree.checkout_state_path(@order.token, 'address') }
          end
        else
          redirect_back(fallback_location: spree.account_addresses_path)
        end
      elsif params[:from_modal].present?
        render turbo_stream: turbo_stream.update("edit_address_modal_#{@address.id}", partial: 'spree/account/addresses/edit_address_modal', locals: { address: @address }), status: :unprocessable_entity
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @address.destroy

      redirect_to(spree.account_addresses_path, status: :see_other, notice: Spree.t('address_book.successfully_removed'))
    end

    private

    def address_params
      params.require(:address).permit(permitted_address_attributes)
    end

    def create_service
      Spree.address_create_service
    end

    def update_service
      Spree.address_update_service
    end

    def load_and_authorize_address
      action = params[:action].to_sym

      @address ||= if [:new, :create].include?(action)
                    Spree::Address.new(country: current_store.default_country, user: try_spree_current_user)
                  else
                    Spree::Address.find_by_param!(params[:id])
                  end

      authorize! action, @address
    end

    def address_changes_except
      []
    end
  end
end
