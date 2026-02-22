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
        store_serializer_exists?(record) || admin_serializer_exists?(record)
      end

      def store_serializer_exists?(record)
        store_serializer_for(record).present?
      end

      def admin_serializer_exists?(record)
        admin_serializer_for(record).present?
      end

      def serialize_to_json(record, api_type: :store)
        return unless record

        serializer = case api_type.to_sym
                     when :store
                       store_serializer_for(record)
                     when :admin
                       admin_serializer_for(record)
                     end

        return nil unless serializer

        # Alba serializers use .new(object, params: {}).to_h
        serialized_hash = serializer.new(
          record,
          params: serializer_params(record, api_type)
        ).to_h

        JSON.pretty_generate(serialized_hash)
      end

      private

      def store_serializer_for(record)
        serializer_for(record, namespace: 'Spree::Api::V3')
      end

      def admin_serializer_for(record)
        serializer_for(record, namespace: 'Spree::Api::V3::Admin')
      end

      def serializer_for(record, namespace:)
        class_name = record.class.name.demodulize

        # First try dependency lookup (without prefix for v3)
        method_name = "#{class_name.underscore}_serializer"
        if namespace == 'Spree::Api::V3' && Spree.api.respond_to?(method_name)
          return Spree.api.public_send(method_name)
        end

        # Fall back to direct constant lookup
        serializer_class_name = "#{namespace}::#{class_name}Serializer"
        serializer_class_name.safe_constantize
      end

      def serializer_params(_record, api_type)
        params = {}
        params[:api_type] = api_type
        params[:store] = current_store if defined?(current_store) && current_store.present?
        params[:currency] = current_currency if defined?(current_currency) && current_currency.present?
        params[:locale] = current_locale if defined?(current_locale) && current_locale.present?
        params
      end
    end
  end
end
