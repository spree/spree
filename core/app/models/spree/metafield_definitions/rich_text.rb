module Spree
  module MetafieldDefinitions
    class RichText < Spree::MetafieldDefinition
      has_rich_text :value
    end
  end
end
