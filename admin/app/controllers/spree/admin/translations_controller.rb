module Spree
  module Admin
    class TranslationsController < Spree::Admin::BaseController
      before_action :set_resource, only: [:edit, :update]
      before_action :load_data, only: [:edit, :update]
      before_action :set_translation_locale, only: [:edit, :update]
      helper_method :normalized_locale
      helper_method :resource_class

      def edit; end

      def normalized_locale(locale)
        locale.to_s.downcase.tr('-', '_')
      end

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

      def translation_fields(klass)
        klass.translatable_fields.map { |field| "#{field}_#{normalized_locale(@selected_translation_locale)}" }
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
        raw_locale = params[:translation_locale].presence ||
             @locales&.first ||
             current_store.default_locale ||
             current_store.supported_locales_list.first

        @selected_translation_locale = normalized_locale(raw_locale)
      end

      def load_data
        @locales = (current_store.supported_locales_list - [@default_locale]).sort
      end
    end
  end
end
