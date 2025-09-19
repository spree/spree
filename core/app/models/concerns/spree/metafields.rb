module Spree
  module Metafields
    extend ActiveSupport::Concern

    included do
      # New metafields association
      has_many :metafields, as: :owner, class_name: 'Spree::Metafield', dependent: :destroy
      has_many :public_metafields, -> { available_on_front_end }, class_name: 'Spree::Metafield'
      has_many :private_metafields, -> { available_on_back_end }, class_name: 'Spree::Metafield'

      accepts_nested_attributes_for :metafields, allow_destroy: true, reject_if: lambda { |mf|
                                                                                     mf[:metafield_definition_id].blank? || (mf[:id].blank? && mf[:value].blank?)
                                                                                   }

      scope :with_metafield, ->(key) { joins(:metafield_definitions).where(spree_metafield_definitions: { key: key }) }
      scope :with_metafield_key_value, ->(key, value) { joins(:metafield_definitions).where(spree_metafield_definitions: { key: key, value: value }) }
    end

    def set_metafield(key, value)
      key = key.to_s.parameterize
      metafield_definition = Spree::MetafieldDefinition.find_or_create_by(key: key, owner_type: self.class.name)

      metafield = metafields.find_or_initialize_by(metafield_definition: metafield_definition)
      metafield.value = value
      metafield.save!
      metafield
    end

    def get_metafield(key)
      key = key.to_s.parameterize
      metafields.with_key(key).first
    end
  end
end
