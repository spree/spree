module Spree
  # Centralized configuration for Ransack searchable attributes, associations, and scopes.
  #
  # This class allows developers to extend Spree models with custom ransackable
  # configurations without using decorators.
  #
  # @example Adding custom searchable fields
  #   Spree.ransack.add_attribute(Spree::Product, :vendor_id)
  #   Spree.ransack.add_scope(Spree::Product, :by_vendor)
  #   Spree.ransack.add_association(Spree::Product, :vendor)
  #
  class RansackConfiguration
    def initialize
      @custom_attributes = Hash.new { |h, k| h[k] = [] }
      @custom_associations = Hash.new { |h, k| h[k] = [] }
      @custom_scopes = Hash.new { |h, k| h[k] = [] }
    end

    # Add a custom ransackable attribute to a model.
    #
    # @param model [Class] the model class to configure (e.g., Spree::Product)
    # @param attribute [String, Symbol] the attribute to add
    # @return [Array<String>] the updated list of custom attributes
    def add_attribute(model, attribute)
      @custom_attributes[model.name.to_sym] |= [attribute.to_s]
    end

    # Add a custom ransackable association to a model.
    #
    # @param model [Class] the model class to configure (e.g., Spree::Product)
    # @param association [String, Symbol] the association to add
    # @return [Array<String>] the updated list of custom associations
    def add_association(model, association)
      @custom_associations[model.name.to_sym] |= [association.to_s]
    end

    # Add a custom ransackable scope to a model.
    #
    # @param model [Class] the model class to configure (e.g., Spree::Product)
    # @param scope [String, Symbol] the scope to add
    # @return [Array<String>] the updated list of custom scopes
    def add_scope(model, scope)
      @custom_scopes[model.name.to_sym] |= [scope.to_s]
    end

    # Get custom ransackable attributes for a model.
    #
    # @param model [Class] the model class to query
    # @return [Array<String>] the custom attributes
    def custom_attributes_for(model)
      @custom_attributes[model.name.to_sym]
    end

    # Get custom ransackable associations for a model.
    #
    # @param model [Class] the model class to query
    # @return [Array<String>] the custom associations
    def custom_associations_for(model)
      @custom_associations[model.name.to_sym]
    end

    # Get custom ransackable scopes for a model.
    #
    # @param model [Class] the model class to query
    # @return [Array<String>] the custom scopes
    def custom_scopes_for(model)
      @custom_scopes[model.name.to_sym]
    end

    # Reset all custom configurations. Useful for testing.
    #
    # @return [void]
    def reset!
      @custom_attributes.clear
      @custom_associations.clear
      @custom_scopes.clear
    end
  end
end
