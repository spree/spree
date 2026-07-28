# frozen_string_literal: true

module Spree
  # Sanitizes rich text attributes through {Spree::RichTextSanitizer} before
  # they hit the database, covering every writer path that ends in a save
  # (Admin API, CSV import, console, translations upsert).
  module SanitizableRichText
    extend ActiveSupport::Concern

    class_methods do
      # Installs a +before_save+ pass sanitizing each named attribute. Only
      # attributes that actually changed are rewritten, so unrelated saves
      # never touch stored content.
      #
      # @param attributes [Array<Symbol>] rich text attribute names
      # @return [void]
      def sanitizes_rich_text(*attributes)
        attributes = attributes.map(&:to_s)

        before_save do
          attributes.each do |attribute|
            next unless will_save_change_to_attribute?(attribute)

            value = self[attribute]
            next if value.blank?

            self[attribute] = Spree::RichTextSanitizer.sanitize(value)
          end
        end
      end
    end
  end
end
