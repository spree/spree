module Spree
  module Workflows
    # Context is simply a HashWithIndifferentAccess for sharing data between steps.
    # Using a type alias for clarity and potential future extension.
    Context = ActiveSupport::HashWithIndifferentAccess
  end
end
