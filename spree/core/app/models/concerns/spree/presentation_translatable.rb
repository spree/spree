module Spree
  # Constant alias for the legacy Spree::PresentationTranslatable, renamed to
  # Spree::LabelTranslatable in 6.0 along with the column it wrapped.
  # Remove in 6.1.
  PresentationTranslatable = LabelTranslatable
end
