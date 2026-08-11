# frozen_string_literal: true

module Spree
  class CustomFieldDefinition
    module SearchCapabilities
      extend ActiveSupport::Concern

      included do
        attribute :searchable, :boolean, default: false
        attribute :sortable, :boolean, default: false

        validate :search_sort_capabilities_compatible_with_type
        validate :filter_key_must_be_unique

        scope :searchable, -> { where(searchable: true) }
        scope :sortable, -> { where(sortable: true) }
      end

      class_methods do
        # @return [Array<String>] API field_type tokens whose STI class is searchable
        def searchable_field_type_tokens
          @searchable_field_type_tokens ||= build_field_type_tokens(&:searchable?)
        end

        # @return [Array<String>] API field_type tokens whose STI class is sortable
        def sortable_field_type_tokens
          @sortable_field_type_tokens ||= build_field_type_tokens(&:sortable?)
        end

        private

        # Builds API tokens from {Spree::CustomFieldDefinition.available_types}
        # (`Spree.custom_fields.types` — in-memory registry, not a DB query).
        def build_field_type_tokens(&block)
          available_types.filter_map do |klass|
            next unless block.call(klass)

            Spree::CustomField::TYPE_CLASS_TO_TOKEN[klass.to_s] || klass.to_s
          end
        end
      end

      # Public identifier for sorting and filtering product listings by this
      # custom field (+sort=cf_specs_material+,
      # +q[cf_specs_material_i_cont]=wool+).
      #
      # @return [String] e.g. +cf_custom_label+
      def filter_key
        "cf_#{namespace}_#{key}"
      end

      private

      # `key` is already unique per (resource_type, namespace), but both
      # segments normalize to underscored slugs, so two different splits
      # ("a_b"/"c" vs "a"/"b_c") flatten to one filter_key — which would make
      # one of them unaddressable as a sort/filter param.
      def filter_key_must_be_unique
        return if namespace.blank? || key.blank? || resource_type.blank?
        return unless new_record? || namespace_changed? || key_changed? || resource_type_changed?

        table = self.class.arel_table
        concatenated = Arel::Nodes::NamedFunction.new(
          'CONCAT', [table[:namespace], Arel::Nodes.build_quoted('_'), table[:key]]
        )

        scope = self.class.
                for_resource_type(resource_type).
                where(concatenated.eq("#{namespace}_#{key}")).
                where(self.class.spree_base_uniqueness_scope.index_with { |attr| public_send(attr) })
        scope = scope.where.not(id: id) if persisted?

        errors.add(:key, :taken) if scope.exists?
      end

      def field_type_class
        field_type_class_name.presence&.safe_constantize
      end

      def search_sort_capabilities_compatible_with_type
        return unless searchable? || sortable?

        klass = field_type_class
        return if klass.nil?

        %i[searchable sortable].each do |capability|
          next unless public_send("#{capability}?")
          next if klass.public_send("#{capability}?")

          errors.add(capability, capability_error_message(capability))
        end
      end

      def capability_error_message(capability)
        labels = self.class
                     .public_send("#{capability}_field_type_tokens")
                     .map { |token| token.tr('_', ' ') }
                     .join(', ')

        "is only supported for field types: #{labels}"
      end
    end
  end
end
