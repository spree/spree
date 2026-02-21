module Spree
  module Admin
    class StoresController < Spree::Admin::BaseController
      include Spree::Admin::SettingsConcern

      before_action :load_store, only: [:edit, :update]
      before_action :normalize_supported_currencies, only: [:update]
      before_action :normalize_supported_locales, only: [:update]
      before_action :load_all_countries, only: [:edit, :update]

      def edit
        if params[:section] == 'emails'
          add_breadcrumb Spree.t(:emails), spree.edit_admin_store_path(section: params[:section])
        elsif params[:section] == 'policies'
          add_breadcrumb Spree.t(:policies), spree.edit_admin_store_path(section: params[:section])
        elsif params[:section] == 'checkout'
          add_breadcrumb Spree.t(:checkout), spree.edit_admin_store_path(section: params[:section])
        else
          add_breadcrumb Spree.t(:store_details), spree.edit_admin_store_path(section: params[:section])
        end
      end

      def edit_emails; end

      def update
        @store.assign_attributes(permitted_store_params)

        if @store.save
          remove_assets(%w[logo mailer_logo], object: @store)
          respond_to do |format|
            format.turbo_stream { flash.now[:success] = flash_message_for(@store, :successfully_updated) }
            format.html { flash[:success] = flash_message_for(@store, :successfully_updated) }
          end
        else
          flash[:error] = "#{Spree.t('store_errors.unable_to_update')}: #{@store.errors.full_messages.join(', ')}"
        end

        if @store.saved_changes? && permitted_store_params[:code].present? && spree.respond_to?(:admin_custom_domains_url)
          redirect_to spree.admin_custom_domains_url(host: @store.url), allow_other_host: true
        else
          respond_to do |format|
            format.turbo_stream
            format.html { redirect_to spree.edit_admin_store_path(section: params[:section]) }
          end
        end
      end

      protected

      def permitted_store_params
        params.require(:store).permit(permitted_store_attributes + current_store.preferences.keys.map { |key| "preferred_#{key}" })
      end

      private

      def load_store
        @store = current_store
      end

      def load_all_countries
        @countries = Spree::Country.pluck(:name, :id)
      end

      def normalize_supported_currencies
        if params.dig(:store, :supported_currencies)&.is_a?(Array)
          params[:store][:supported_currencies] = params[:store][:supported_currencies].compact.uniq.reject(&:blank?).join(',')
        end
      end

      def normalize_supported_locales
        if params.dig(:store, :supported_locales)&.is_a?(Array)
          params[:store][:supported_locales] = params[:store][:supported_locales].compact.uniq.reject(&:blank?).join(',')
        end
      end
    end
  end
end
