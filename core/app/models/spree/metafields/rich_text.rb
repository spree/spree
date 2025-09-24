module Spree
  module Metafields
    class RichText < Spree::Metafield
      has_rich_text :value

      def serialize_value
        value.body.to_s
      end
    end
  end
end
