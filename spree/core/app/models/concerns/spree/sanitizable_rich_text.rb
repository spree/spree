# frozen_string_literal: true

module Spree
  # Sanitizes rich text attributes through {Spree::RichTextSanitizer} before
  # they hit the database, covering every writer path that ends in a save
  # (Admin API, CSV import, console, translations upsert).
  #
  # Callback-bypassing writes — +update_columns+, +update_all+, raw SQL — are
  # NOT covered by design; call {Spree::RichTextSanitizer.sanitize} explicitly
  # when writing rich text through those paths.
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

      # Declares the API's read/write pair for a rich text attribute: reads
      # expose +field+ (plain text) and +field_html+ (HTML), and writes go
      # through +field_html+. The model owns this bridge so clients never have
      # to translate field names between reading and writing.
      #
      # Pair with {#sanitizes_rich_text} — the writer only assigns, leaving the
      # +before_save+ pass as the single place sanitization happens.
      #
      # Both sides delegate to the plain attribute's own accessors rather than
      # +self[]+, so translated fields keep going through Mobility and resolve
      # against the active locale.
      #
      # @param attributes [Array<Symbol>] rich text attribute names
      # @return [void]
      def rich_text_html_accessor(*attributes)
        attributes.each do |attribute|
          define_method(:"#{attribute}_html") { public_send(attribute).to_s }
          define_method(:"#{attribute}_html=") { |value| public_send(:"#{attribute}=", value) }
        end
      end
    end
  end
end
