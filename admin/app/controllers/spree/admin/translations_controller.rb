module Spree
  module Admin
    class TranslationsController < Spree::Admin::BaseController
      # Set the resource being translated and any related data
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit, :update]
      before_action :set_translation_locale, only: [:edit, :update]
      helper_method :normalized_locale
      helper_method :resource_class

      # GET /admin/translations/:id/edit
      # Renders the edit translation page for the resource
      def edit; end

      # Normalizes a locale string by replacing '-' with '_' and downcasing
      def normalized_locale(locale)
        locale.to_s.downcase.tr('-', '_')
      end

      # PUT /admin/translations/:id
      # Updates the translations for the resource
      # Sets flash messages for success or failure
      def update
        if @resource.update(permitted_translation_params)
          flash.now[:success] = flash_message_for(@resource, :successfully_updated)
        else
          flash.now[:error] = @resource.errors.full_messages.to_sentence
        end
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

      # Build translation field names with normalized locale suffix
      def translation_fields(klass)
        klass.translatable_fields.map { |field| "#{field}_#{normalized_locale(@selected_translation_locale)}" }
      end

      # Determine the class of the resource
      def resource_class
        @resource_class ||= begin
          klass = params[:resource_type]
          allowed_resource_class.find { |allowed_class| allowed_class.to_s == klass } ||
            raise(ActiveRecord::RecordNotFound, "Resource type not found")
        end
      end

      # Allowed translatable resources configured in Spree
      def allowed_resource_class
        Rails.application.config.spree.translatable_resources
      end

      # Set the resource object using friendly find if available
      def set_resource
        @resource = if resource_class.respond_to?(:friendly)
                      resource_class.friendly.find(params[:id])
                    else
                      resource_class.find(params[:id])
                    end
      end

      # Determine the translation locale to use
      def set_translation_locale
        raw_locale = params[:translation_locale].presence ||
        @locales&.first ||
        current_store.default_locale ||
        current_store.supported_locales_list.first

        @selected_translation_locale = normalized_locale(raw_locale)
      end

      # Load available locales for this resource, excluding default
      def load_data
        @locales = (current_store.supported_locales_list - [@default_locale]).sort
      end
    end
  end
end
