module Spree
  module Admin
    module MultiStore
      class StoresController < Spree::Admin::BaseController
        def new
          @store = Spree::Store.new
          render :new, layout: 'spree/admin_wizard'
        end

        def create
          @store = Spree::Store.new(permitted_store_params)
          @store.mail_from_address = current_store.mail_from_address

          if @store.save
            # Move/copy all existing users (staff) to the new store
            current_store.role_users.each do |role_user|
              @store.add_user(role_user.user, role_user.role)
            end

            flash[:success] = flash_message_for(@store, :successfully_created)
            redirect_to spree.admin_getting_started_url(host: @store.url), allow_other_host: true
          else
            render :new, status: :unprocessable_content
          end
        end

        protected

        def permitted_store_params
          params.require(:store).permit(permitted_store_attributes)
        end
      end
    end
  end
end
