module Spree
  class Metafield < Spree.base_class
    #
    # Associations
    #
    belongs_to :owner, polymorphic: true
    belongs_to :metafield_definition, class_name: 'Spree::MetafieldDefinition'

    #
    # Validations
    #
    validates :value, :metafield_definition, :owner, presence: true
    validates :metafield_definition_id, uniqueness: { scope: [:owner_type, :owner_id] }

    #
    # Scopes
    #
    scope :available_on_front_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_front_end) }
    scope :available_on_back_end, -> { joins(:metafield_definition).merge(Spree::MetafieldDefinition.available_on_back_end) }

    delegate :key, :kind, :name, :display_on, to: :metafield_definition

    def value=(val)
      case kind
      when 'number'
        super(val.to_i)
      when 'boolean'
        super(ActiveModel::Type::Boolean.new.cast(val))
      when 'json'
        super(val.is_a?(String) ? JSON.parse(val) : val)
      when 'short_text', 'long_text', 'rich_text'
        super(val.to_s)
      else
        super(val.to_s)
      end
    rescue JSON::ParserError
      super(val.to_s)
    end

    def typed_value
      case kind
      when 'number'
        value.to_i
      when 'boolean'
        ActiveModel::Type::Boolean.new.cast(value)
      when 'json'
        value.is_a?(String) ? JSON.parse(value) : value
      when 'short_text', 'long_text', 'rich_text'
        value.to_s
      else
        value.to_s
      end
    rescue JSON::ParserError
      value.to_s
    end
  end
end
