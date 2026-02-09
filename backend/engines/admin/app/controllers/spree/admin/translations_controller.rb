module Spree
  module Admin
    class TranslationsController < ResourceController
      # Set the resource being translated and any related data
      before_action :load_data
      before_action :set_translation_locale
      helper_method :normalized_locale

      # Normalizes a locale string by replacing '-' with '_' and downcasing
      def normalized_locale(locale)
        locale.to_s.downcase.tr('-', '_')
      end

      private

      def permitted_resource_params
        params.require(@object.model_name.param_key).permit(translation_fields(model_class), **nested_params)
      end

      def nested_params
        case model_class.to_s
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
      def model_class
        @model_class ||= begin
          klass = params[:resource_type]
          allowed_model_classes.find { |allowed_class| allowed_class.to_s == klass } ||
            raise(ActiveRecord::RecordNotFound, "Resource type not found")
        end
      end

      # Allowed translatable resources configured in Spree
      def allowed_model_classes
        Spree.translatable_resources
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

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
