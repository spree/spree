module Spree
  module Metafields
    class RichText < Spree::Metafield
      has_rich_text :value
    end
  end
end
