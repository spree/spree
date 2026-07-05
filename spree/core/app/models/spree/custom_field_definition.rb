module Spree
  # Constant alias for the legacy Spree::MetafieldDefinition class. Lets
  # controllers, serializers, and 5.5+ extensions reference the model by its
  # 6.0-bound name without the actual class rename (which lands with the table
  # rename in 6.0).
  CustomFieldDefinition = MetafieldDefinition
end
