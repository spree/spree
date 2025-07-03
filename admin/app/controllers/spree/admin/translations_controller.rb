module Spree
  module Admin
    class TranslationsController < Spree::Admin::BaseController
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit]
      before_action :set_translation_locale, only: [:edit, :update]

      def edit; end

      def update
        @resource.update!(permitted_translation_params)

        flash[:success] = Spree.t('notice_messages.translations_saved')

        redirect_to spree.edit_admin_translation_path(
          @resource,
          resource_type: @resource.class.to_s,
          translation_locale: @selected_translation_locale
        )
      end

      private

      def permitted_translation_params
        params.require(@resource.model_name.param_key).permit(translation_fields(resource_class), **nested_params)
      end

      def nested_params
        case resource_class.to_s
          when 'Spree::OptionType'
            { option_values_attributes: [ :id, *translation_fields(Spree::OptionValue)] }
          else
            {}
        end
      end

      def translation_fields(klass)
        klass.translatable_fields.map { |field| "#{field}_#{@selected_translation_locale}" }
      end

      def resource_class
        @resource_class ||= begin
          klass = params[:resource_type]
          allowed_resource_class.find { |allowed_class| allowed_class.to_s == klass } ||
            raise(ActiveRecord::RecordNotFound, "Resource type not found")
        end
      end

      def allowed_resource_class
        Rails.application.config.spree.translatable_resources
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
        @resource_name = @resource.try(:name)

        @back_path = case @resource.class.name
          when 'Spree::OptionType'
            spree.edit_admin_option_type_path(@resource)
          when 'Spree::Product'
            spree.edit_admin_product_path(@resource)
          when 'Spree::Property'
            spree.edit_admin_property_path(@resource)
          when 'Spree::Store'
            spree.edit_admin_store_path(section: "general-settings")
          when 'Spree::Taxon'
            spree.edit_admin_taxonomy_taxon_path(@resource.taxonomy, @resource.id)
          when 'Spree::Taxonomy'
            spree.admin_taxonomy_path(@resource)
          else
            [:edit, :admin, @resource]
        end
      end
    end
  end
end
