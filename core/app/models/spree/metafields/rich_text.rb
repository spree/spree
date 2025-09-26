module Spree
  module Metafields
    class RichText < Spree::Metafield
      # Avoid collision with the `value` column used by other metafield types
      self.ignored_columns = %w[value]

      has_rich_text :value

      def serialize_value
        value&.body&.to_s
      end
    end
  end
end
