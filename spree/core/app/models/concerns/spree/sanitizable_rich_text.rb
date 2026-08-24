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

    included do
      # Which attributes on this class hold rich text. Lets callers that need
      # to search stored markup — the media library's "where is this file
      # used" — find the columns without hardcoding a list that goes stale the
      # moment a model gains a field.
      class_attribute :spree_rich_text_attributes, instance_writer: false, default: [].freeze
    end

    # Every model declaring rich text, with the attributes it declared.
    #
    # Walks descendants of the base class rather than keeping a registry: a
    # registry populated at class-definition time is empty under Rails' lazy
    # loading until something references each model.
    #
    # @return [Hash{Class => Array<String>}]
    def self.declaring_models
      Spree.base_class.descendants.each_with_object({}) do |model, found|
        next if model.abstract_class?
        next unless model.respond_to?(:spree_rich_text_attributes)

        attributes = model.spree_rich_text_attributes
        found[model] = attributes if attributes.present?
      end
    end

    class_methods do
      # Declares a rich text attribute: sanitized on save, and readable as
      # +field_html+ for the raw markup. This is what a model wants.
      #
      #   has_spree_rich_text :description
      #
      # A translated attribute needs the same declaration on the +Translation+
      # class, because Mobility writes bypass the parent's callbacks — but only
      # to sanitize, since the reader belongs on the parent:
      #
      #   self::Translation.class_eval do
      #     include Spree::SanitizableRichText
      #     sanitizes_rich_text :description
      #   end
      #
      # @param attributes [Array<Symbol>] rich text attribute names
      # @return [void]
      def has_spree_rich_text(*attributes)
        sanitizes_rich_text(*attributes)
        rich_text_html_reader(*attributes)
      end

      # Installs a +before_save+ pass sanitizing each named attribute. Only
      # attributes that actually changed are rewritten, so unrelated saves
      # never touch stored content.
      #
      # Prefer {#has_spree_rich_text} — reach for this alone only where the
      # +field_html+ reader doesn't belong, i.e. on a Mobility +Translation+
      # class or a model that serializes the value some other way.
      #
      # @param attributes [Array<Symbol>] rich text attribute names
      # @return [void]
      def sanitizes_rich_text(*attributes)
        attributes = attributes.map(&:to_s)

        if respond_to?(:spree_rich_text_attributes)
          # Union, not assignment — a decorator declaring one more field must
          # not drop what the class already declared.
          self.spree_rich_text_attributes = (spree_rich_text_attributes | attributes).freeze
        end

        before_save do
          attributes.each do |attribute|
            next unless will_save_change_to_attribute?(attribute)

            value = self[attribute]
            next if value.blank?

            self[attribute] = Spree::RichTextSanitizer.sanitize(value)
          end
        end
      end

      # Defines +field_html+, the raw stored markup. The API exposes it beside
      # the plain +field+, which serializers render as text — writes use the
      # plain name, since the value is HTML either way.
      #
      # Reads through the attribute's own reader rather than +self[]+, so a
      # translated field still goes through Mobility and resolves against the
      # active locale.
      #
      # @param attributes [Array<Symbol>] rich text attribute names
      # @return [void]
      def rich_text_html_reader(*attributes)
        attributes.each do |attribute|
          define_method(:"#{attribute}_html") { public_send(attribute).to_s }
        end
      end
    end
  end
end
