module Spree
  module Metafields
    extend ActiveSupport::Concern

    included do
      # New metafields association
      has_many :metafields, -> { includes(:metafield_definition) }, as: :resource, class_name: 'Spree::Metafield', dependent: :destroy
      has_many :public_metafields, -> { includes(:metafield_definition).available_on_front_end }, class_name: 'Spree::Metafield'
      has_many :private_metafields, -> { includes(:metafield_definition).available_on_back_end }, class_name: 'Spree::Metafield'

      accepts_nested_attributes_for :metafields, allow_destroy: true, reject_if: lambda { |mf|
                                                                                     mf[:metafield_definition_id].blank? || mf[:type].blank? || (mf[:id].blank? && mf[:value].blank?)
                                                                                   }

      scope :with_metafield_key, ->(namespace, key) { joins(:metafield_definitions).where(spree_metafield_definitions: { namespace: namespace, key: key }) }
      scope :with_metafield_key_value, ->(namespace, key, value) { joins(:metafield_definitions).where(spree_metafield_definitions: { namespace: namespace, key: key, value: value }) }

      def set_metafield(key_with_namespace, value)
        namespace = key_with_namespace.to_s.split('.').first
        key = key_with_namespace.to_s.split('.').last
        metafield_definition = Spree::MetafieldDefinition.find_or_create_by(namespace: namespace, key: key, resource_type: self.class.name)

        metafield = metafields.find_or_initialize_by(metafield_definition: metafield_definition)
        metafield.value = value
        metafield.save!
        metafield
      end

      def get_metafield(key_with_namespace)
        namespace = key_with_namespace.to_s.split('.').first
        key = key_with_namespace.to_s.split('.').last
        metafields.with_key(namespace, key).first
      end

      def has_metafield?(key_with_namespace)
        if key_with_namespace.is_a?(Spree::MetafieldDefinition)
          namespace = key_with_namespace.namespace
          key = key_with_namespace.key
        elsif key_with_namespace.is_a?(String)
          namespace = key_with_namespace.to_s.split('.').first
          key = key_with_namespace.to_s.split('.').last
        else
          raise ArgumentError, "Invalid key_with_namespace: #{key_with_namespace.inspect}"
        end

        metafields.with_key(namespace, key).exists?
      end
    end
  end
end
