module Spree
  module Admin
    module JsonPreviewHelper
      def link_to_show_json(record, options = {})
        return unless json_serializers_available?(record)
        return unless can?(:read, record)
        return unless can?(:read, :json_preview)

        options[:class] ||= 'dropdown-item'
        options[:data] ||= { action: 'drawer#open', turbo_frame: :drawer }

        link_to_with_icon(
          'code',
          Spree.t('admin.show_json'),
          spree.admin_json_preview_resource_path(record.id, resource_type: record.class.to_s),
          options
        )
      end

      def json_serializers_available?(record)
        storefront_serializer_exists?(record) || platform_serializer_exists?(record)
      end

      def storefront_serializer_exists?(record)
        serializer_class_name = "Spree::V2::Storefront::#{record.class.name.demodulize}Serializer"
        serializer_class_name.safe_constantize.present?
      end

      def platform_serializer_exists?(record)
        serializer_class_name = "Spree::Api::V2::Platform::#{record.class.name.demodulize}Serializer"
        serializer_class_name.safe_constantize.present?
      end

      def serialize_to_json(record, api_type: :storefront)
        return unless record

        serializer = case api_type.to_sym
                     when :storefront
                       storefront_serializer_for(record)
                     when :platform
                       platform_serializer_for(record)
                     end

        return nil unless serializer

        serializable_hash = serializer.new(
          record,
          params: serializer_params(record)
        ).serializable_hash

        JSON.pretty_generate(serializable_hash)
      end

      private

      def storefront_serializer_for(record)
        serializer_class_name = "Spree::V2::Storefront::#{record.class.name.demodulize}Serializer"
        serializer_class_name.safe_constantize
      end

      def platform_serializer_for(record)
        serializer_class_name = "Spree::Api::V2::Platform::#{record.class.name.demodulize}Serializer"
        serializer_class_name.safe_constantize
      end

      def serializer_params(record)
        params = {}
        params[:store] = current_store if defined?(current_store) && current_store.present?
        params[:currency] = current_currency if defined?(current_currency) && current_currency.present?
        params[:locale] = current_locale if defined?(current_locale) && current_locale.present?
        params
      end
    end
  end
end
