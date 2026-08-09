module Spree
  module CustomFields
    # Stores sanitized HTML in the shared `value` text column like every other
    # custom field type. ActionText is gone in 6.0
    # (docs/plans/6.0-rich-text-descriptions.md) — it round-tripped Tiptap
    # markup through Trix's narrower allowlist, corrupting content on save.
    class RichText < Spree::CustomField
      include Spree::SanitizableRichText

      sanitizes_rich_text :value

      def serialize_value
        value
      end

      def csv_value
        return '' if value.blank?

        Nokogiri::HTML.fragment(value).text
      end
    end
  end
end
