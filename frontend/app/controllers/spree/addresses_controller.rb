# https://github.com/spree-contrib/spree_address_book/blob/master/app/controllers/spree/addresses_controller.rb
module Spree
  class AddressesController < Spree::StoreController
    helper Spree::AddressesHelper
    load_and_authorize_resource class: Spree::Address

    def create
      @address = try_spree_current_user.addresses.build(address_params)
      if create_service.call(user: try_spree_current_user, address_params: @address.attributes).success?
        flash[:notice] = I18n.t(:successfully_created, scope: :address_book)
        redirect_to spree.account_path
      else
        render action: 'new'
      end
    end

    def edit
      session['spree_user_return_to'] = request.env['HTTP_REFERER']
    end

    def new
      @address = Spree::Address.new(country: current_store.default_country, user: try_spree_current_user)
    end

    def update
      if update_service.call(address: @address, address_params: address_params).success?
        flash[:notice] = Spree.t(:successfully_updated, scope: :address_book)
        redirect_back_or_default(addresses_path)
      else
        render :edit
      end
    end

    def destroy
      @address.destroy

      flash[:notice] = Spree.t(:successfully_removed, scope: :address_book)
      redirect_to(request.env['HTTP_REFERER'] || addresses_path) unless request.xhr?
    end

    private

    def address_params
      params.require(:address).permit(permitted_address_attributes)
    end

    def create_service
      Spree::Dependencies.account_create_address_service.constantize
    end

    def update_service
      Spree::Dependencies.account_update_address_service.constantize
    end
  end
end
