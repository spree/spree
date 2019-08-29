# https://github.com/spree-contrib/spree_address_book/blob/master/app/controllers/spree/addresses_controller.rb
module Spree
  class AddressesController < Spree::StoreController
    helper Spree::AddressesHelper
    load_and_authorize_resource class: Spree::Address

    def index
      @addresses = spree_current_user.addresses
    end

    def create
      @address = spree_current_user.addresses.build(address_params)
      if @address.save
        flash[:notice] = Spree.t(:successfully_created, scope: :address_book)
        redirect_to :index
      else
        render :new
      end
    end

    def edit
      session['spree_user_return_to'] = request.env['HTTP_REFERER']
    end

    def new
      @address = Spree::Address.default
    end

    def update
      if @address.editable?
        if @address.update(address_params)
          flash[:notice] = Spree.t(:successfully_updated, scope: :address_book)
          redirect_back_or_default(addresses_path)
        else
          render :edit
        end
      else
        new_address = @address.clone
        new_address.attributes = address_params
        @address.update_attribute(:deleted_at, Time.current)
        if new_address.save
          flash[:notice] = Spree.t(:successfully_updated, scope: :address_book)
          redirect_back_or_default(addresses_path)
        else
          render :edit
        end
      end
    end

    def destroy
      @address.destroy

      flash[:notice] = Spree.t(:successfully_removed, scope: :address_book)
      redirect_to(request.env['HTTP_REFERER'] || addresses_path) unless request.xhr?
    end

    private

    def address_params
      params[:address].permit(:address,
                              :firstname,
                              :lastname,
                              :address1,
                              :address2,
                              :city,
                              :state_id,
                              :zipcode,
                              :country_id,
                              :phone)
    end
  end
end
