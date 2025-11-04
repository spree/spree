module Spree
  module Metafields
    extend ActiveSupport::Concern

    module ClassMethods
      def ensure_metafield_definition_exists!(key_with_namespace)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        Spree::MetafieldDefinition.find_or_create_by!(namespace: namespace, key: key, resource_type: self.name)
      end

      def extract_namespace_and_key(key_with_namespace)
        namespace = key_with_namespace.to_s.split('.').first
        key = key_with_namespace.to_s.split('.').last
        [namespace, key]
      end
    end

    included do
      has_many :metafields, -> { includes(:metafield_definition) }, as: :resource, class_name: 'Spree::Metafield', dependent: :destroy
      has_many :public_metafields, -> { includes(:metafield_definition).available_on_front_end }, as: :resource, class_name: 'Spree::Metafield'
      has_many :private_metafields, -> { includes(:metafield_definition).available_on_back_end }, as: :resource, class_name: 'Spree::Metafield'

      accepts_nested_attributes_for :metafields, allow_destroy: true, reject_if: lambda { |mf|
                                                                                     mf[:metafield_definition_id].blank? || (mf[:id].blank? && mf[:value].blank?)
                                                                                   }

      # Override metafields_attributes= to automatically mark existing metafields
      # with empty values for destruction
      def metafields_attributes=(attributes)
        attributes = attributes.values if attributes.is_a?(Hash)

        attributes.each do |attrs|
          # If this is an existing metafield (has an id) and value is blank,
          # mark it for destruction
          if attrs[:id].present? && value_blank?(attrs[:value])
            attrs[:_destroy] = true
          end
        end

        super(attributes)
      end

      scope :with_metafield_key, ->(key_with_namespace) {
        namespace, key = extract_namespace_and_key(key_with_namespace)
        joins(metafields: :metafield_definition).where(spree_metafield_definitions: { namespace: namespace, key: key })
      }
      scope :with_metafield_key_value, ->(key_with_namespace, value) {
        namespace, key = extract_namespace_and_key(key_with_namespace)

        joins(metafields: :metafield_definition)
          .where(spree_metafield_definitions: { namespace: namespace, key: key })
          .where(spree_metafields: { value: value })
      }

      def extract_namespace_and_key(key_with_namespace)
        self.class.extract_namespace_and_key(key_with_namespace)
      end

      def set_metafield(key_with_namespace, value)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        metafield_definition = Spree::MetafieldDefinition.find_or_create_by!(namespace: namespace, key: key, resource_type: self.class.name)

        metafield = metafields.find_or_initialize_by(metafield_definition: metafield_definition)
        metafield.value = value
        metafield.save!
        metafield
      end

      def get_metafield(key_with_namespace)
        namespace, key = extract_namespace_and_key(key_with_namespace)
        metafields.with_key(namespace, key).first
      end

      def has_metafield?(key_with_namespace)
        if key_with_namespace.is_a?(Spree::MetafieldDefinition)
          namespace = key_with_namespace.namespace
          key = key_with_namespace.key
        elsif key_with_namespace.is_a?(String)
          namespace, key = extract_namespace_and_key(key_with_namespace)
        else
          raise ArgumentError, "Invalid key_with_namespace: #{key_with_namespace.inspect}"
        end

        metafields.with_key(namespace, key).exists?
      end

      private

      def value_blank?(value)
        value.blank?
      end
    end
  end
end
