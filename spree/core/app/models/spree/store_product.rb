module Spree
  # @deprecated Use {Spree::ProductPublication}. Will be removed in Spree 6.0.
  #
  # Subclasses +ProductPublication+ rather than aliasing the constant so
  # Zeitwerk can resolve +Spree::StoreProduct+ via standard autoload. STI's
  # type column is disabled — the two classes are operationally identical.
  class StoreProduct < Spree::ProductPublication
    self.inheritance_column = nil
  end
end
