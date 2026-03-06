module Spree
  module Api
    module V3
      module ResourceSerializer
        extend ActiveSupport::Concern

        protected

        # Serialize a single resource
        def serialize_resource(resource)
          hash = serializer_class.new(resource, params: serializer_params).to_h
          filter_fields(hash)
        end

        # Serialize a collection of resources
        def serialize_collection(collection)
          collection.map do |item|
            hash = serializer_class.new(item, params: serializer_params).to_h
            filter_fields(hash)
          end
        end

        # Params passed to serializers
        def serializer_params
          {
            currency: current_currency,
            store: current_store,
            user: current_user,
            locale: current_locale,
            expand: expand_list
          }
        end

        # Parse expand parameter into list
        # Supports: ?expand=variants,images
        def expand_list
          expand_param = params[:expand].presence
          return [] unless expand_param

          expand_param.to_s.split(',').map(&:strip)
        end

        # Parse fields parameter into a Set for O(1) lookup.
        # Returns nil when no fields param is present (return all fields).
        # Supports: ?fields=name,slug,price
        def fields_list
          return @fields_list if defined?(@fields_list)

          fields_param = params[:fields].presence
          @fields_list = fields_param ? fields_param.to_s.split(',').map(&:strip).to_set : nil
        end

        # Filter serialized hash to only include requested fields.
        # The 'id' field is always included. Expanded associations are always included.
        def filter_fields(hash)
          fields = fields_list
          return hash unless fields

          hash.select { |key, _| key == 'id' || fields.include?(key) || expanded_keys.include?(key) }
        end

        # Top-level expand keys (e.g., 'variants.images' → 'variants')
        def expanded_keys
          @expanded_keys ||= expand_list.map { |e| e.split('.').first }.to_set
        end
      end
    end
  end
end
