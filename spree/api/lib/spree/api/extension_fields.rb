module Spree
  module Api
    # Read-only fields an extension adds to a core serializer's responses —
    # the read side of +additional_permitted_attributes+.
    #
    # A field is registered against a serializer's dependency name, not its
    # class, so a host app that replaces the serializer through +Spree.api+
    # still renders it. Its value is written by the extension's own
    # serializer. Fields are left out of the generated SDK types: the
    # extension that adds one declares its type.
    #
    # @example
    #   Spree.api.extension_fields.register(
    #     :admin_product_serializer, :warranty,
    #     serializer: 'MyExtension::WarrantySerializer', expand: true
    #   )
    class ExtensionFields
      class Field
        attr_reader :name

        def initialize(name:, serializer:, expand:, value:)
          @name = name
          @serializer = serializer
          @expand = expand
          @value = value
        end

        # @return [Boolean] whether the field is shown only when the request expands it
        def expand?
          @expand
        end

        # Run inside the core serializer, so it sees the request's expands.
        # @return [Proc]
        def reader
          field = self
          @reader ||= proc do |object|
            next Alba::REMOVE_KEY if field.expand? && !expand?(field.name)

            field.render(object, params: nested_params(field.name))
          end
        end

        # @param record [Object] the record the core serializer is writing
        # @param params [Hash] the params for the field's serializer, nested expands included
        # @return [Hash, nil]
        def render(record, params:)
          value = @value ? @value.call(record) : record
          return if value.nil?

          serializer_class.new(value, params: params).serializable_hash
        end

        private

        def serializer_class
          @serializer.is_a?(String) ? @serializer.constantize : @serializer
        end
      end

      class DuplicateField < ArgumentError; end

      def initialize
        @fields = Hash.new { |hash, key| hash[key] = {} }
        @class_readers = {}
      end

      # @param dependency [Symbol] the serializer's dependency name, e.g. +:admin_product_serializer+
      # @param name [Symbol, String] the response key
      # @param serializer [Class, String] writes the field's value
      # @param expand [Boolean] true to show the field only when the request expands it
      # @param value [#call, nil] turns the record into the field's value; the record itself when nil
      # @raise [ArgumentError] when the dependency is not a serializer
      # @raise [DuplicateField] when the serializer already has a field of that name
      # @return [void]
      def register(dependency, name, serializer:, expand: false, value: nil)
        dependency = dependency.to_sym
        name = name.to_sym
        # Current names only: a pre-rename key would be resolved through its
        # deprecation warning on every render.
        unless dependency.to_s.end_with?('_serializer') && Spree::Api::Dependencies.class::INJECTION_POINTS.include?(dependency)
          raise ArgumentError, "#{dependency} is not an API serializer"
        end
        if @fields[dependency].key?(name) || Spree.api.public_send(dependency)._attributes.key?(name)
          raise DuplicateField, "#{dependency} already has a field named #{name}"
        end

        @fields[dependency][name] = Field.new(name: name, serializer: serializer, expand: expand, value: value)
        @class_readers[dependency] ||= :"#{dependency}_class"
      end

      # @return [void]
      def unregister(dependency, name)
        @fields[dependency.to_sym].delete(name.to_sym)
      end

      # The fields of every dependency that currently resolves to this class.
      #
      # @param serializer_class [Class]
      # @return [Array<Field>]
      def for(serializer_class)
        @fields.each_with_object([]) do |(dependency, fields), result|
          # The dependency's cached reader, skipping Spree.api's method_missing on every render.
          next if fields.empty? || Spree::Api::Dependencies.public_send(@class_readers[dependency]) != serializer_class

          result.concat(fields.values)
        end
      end
    end
  end
end
