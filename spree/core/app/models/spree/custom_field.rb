module Spree
  # Constant alias for the legacy Spree::Metafield class. Lets controllers,
  # serializers, and 5.5+ extensions reference the model by its 6.0-bound name
  # without the actual class rename (which lands with the table rename in 6.0).
  #
  # This is a true constant alias — the underlying class, table, STI subclasses,
  # and `model_name` are all `Spree::Metafield`. Only the constant name differs.
  CustomField = Metafield
end
