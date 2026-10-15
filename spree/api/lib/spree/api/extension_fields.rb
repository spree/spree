module Spree
  module Api
    # Read-only fields an extension adds to a core serializer's responses —
    # the read side of +additional_permitted_attributes+.
    #
    # A field is registered against a serializer's dependency name, not its
    # class, so a host app that replaces the serializer through +Spree.api+
    # still renders it. An attribute writes its value as it is; an association
    # renders a related record, or a list of them, with the extension's own
    # serializer. Fields are left out of the generated SDK types: the
    # extension that adds one declares its type.
    #
    # @example
    #   Spree.api.extension_fields.attribute(:admin_product_serializer, method: :warranty_text)
    #   Spree.api.extension_fields.association(
    #     :admin_product_serializer, one: :warranty,
    #     serializer: 'MyExtension::WarrantySerializer', expand: true
    #   )
    class ExtensionFields
      # What attributes and associations share: a name, whether it waits for
      # an expand, and where its value comes from.
      class Field
        attr_reader :name

        def initialize(name:, expand:, value:)
          @name = name
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

            field.render(field.value_for(object), params: nested_params(field.name))
          end
        end

        # An extension cannot add a method to a core model, so +value+ can
        # supply the value from the record instead.
        #
        # @param record [Object] the record the core serializer is writing
        # @return [Object]
        def value_for(record)
          @value ? @value.call(record) : record.public_send(name)
        end
      end

      # A value written as it is.
      class Attribute < Field
        # @return [Object]
        def render(value, **)
          value
        end
      end

      # A related record, or a list of them, written by the extension's
      # serializer, which also receives the request's nested expands.
      class Association < Field
        def initialize(serializer:, **)
          super(**)
          @serializer = serializer
        end

        # @return [Hash, Array<Hash>, nil]
        def render(value, params:)
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
      # @param method [Symbol, String] the response key, and the record's method that gives the value
      # @param expand [Boolean] true to show the field only when the request expands it
      # @param value [#call, nil] gives the value from the record instead of calling +method+ on it
      # @raise [ArgumentError] when the dependency is not a serializer
      # @raise [DuplicateField] when the serializer already has a field of that name
      # @return [void]
      def attribute(dependency, method:, expand: false, value: nil)
        add(dependency, Attribute.new(name: method.to_sym, expand: expand, value: value))
      end

      # @param dependency [Symbol] the serializer's dependency name, e.g. +:admin_product_serializer+
      # @param serializer [Class, String] writes each related record
      # @param one [Symbol, String, nil] the response key of a single related record, read from the record's method of that name
      # @param many [Symbol, String, nil] the same, for a list of related records
      # @param expand [Boolean] true to show the field only when the request expands it
      # @param value [#call, nil] gives the related record, or records, instead of calling the method
      # @raise [ArgumentError] when the dependency is not a serializer, or not exactly one of +one+ and +many+ is given
      # @raise [DuplicateField] when the serializer already has a field of that name
      # @return [void]
      def association(dependency, serializer:, one: nil, many: nil, expand: false, value: nil)
        raise ArgumentError, 'Pass either one: or many:' unless one.present? ^ many.present?

        add(dependency, Association.new(name: (one || many).to_sym, serializer: serializer, expand: expand, value: value))
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

      private

      def add(dependency, field)
        dependency = dependency.to_sym
        # Current names only: a pre-rename key would be resolved through its
        # deprecation warning on every render.
        unless dependency.to_s.end_with?('_serializer') && Spree::Api::Dependencies.class::INJECTION_POINTS.include?(dependency)
          raise ArgumentError, "#{dependency} is not an API serializer"
        end
        if @fields[dependency].key?(field.name) || Spree.api.public_send(dependency)._attributes.key?(field.name)
          raise DuplicateField, "#{dependency} already has a field named #{field.name}"
        end

        @fields[dependency][field.name] = field
        @class_readers[dependency] ||= :"#{dependency}_class"
      end
    end
  end
end
