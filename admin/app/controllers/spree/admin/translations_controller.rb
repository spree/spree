module Spree
  module Admin
    class TranslationsController < Spree::Admin::BaseController
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit]
      before_action :set_translation_locale, only: [:edit, :update]

      def edit; end

      def update
        locale_translation_params = permitted_translation_params.to_h.transform_values do |translations|
          translations[@selected_translation_locale]
        end

        Mobility.with_locale(@selected_translation_locale) do
          @resource.update!(locale_translation_params)
        end

        flash[:success] = Spree.t('notice_messages.translations_saved')

        redirect_to spree.edit_admin_translation_path(
          @resource,
          resource_type: @resource.class.to_s,
          translation_locale: @selected_translation_locale
        )
      end

      private

      def permitted_translation_params
        params.require(:translation).permit(
          resource_class.translatable_fields.each_with_object({}) do |field, acc|
            acc[field] = current_store.supported_locales_list.map(&:to_sym)
          end
        )
      end

      def resource_class
        @resource_class ||= params[:resource_type].constantize
      end

      def set_resource
        @resource = if resource_class.respond_to?(:friendly)
                      resource_class.friendly.find(params[:id])
                    else
                      resource_class.find(params[:id])
                    end
      end

      def set_translation_locale
        @selected_translation_locale = params[:translation_locale].presence || @locales&.first || current_store.supported_locales_list.first
      end

      def load_data
        @locales = (current_store.supported_locales_list - [@default_locale]).sort

        case @resource
        when Spree::Product
          @resource_name = @resource.name
          @back_path = spree.edit_admin_product_path(@resource)
        when Spree::Taxon
          @resource_name = @resource.name
          @back_path = spree.edit_admin_taxonomy_taxon_path(@resource.taxonomy, @resource.id)
        when Spree::Taxonomy
          @resource_name = @resource.name
          @back_path = spree.edit_admin_taxonomy_path(@resource)
        when Spree::Store
          @resource_name = @resource.name
          @back_path = spree.edit_admin_store_path(@resource, section: "general-settings")
        end
      end
    end
  end
end
