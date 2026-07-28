# frozen_string_literal: true

module Spree
  # Allowlist sanitizer for rich text HTML stored in plain text columns
  # (e.g. +Spree::Product#description+).
  #
  # The default allowlist is deliberately permissive: legacy descriptions were
  # written with TinyMCE (spans, divs, inline styles, tables, images) and must
  # survive a re-save. It still removes the dangerous surface — +script+,
  # +iframe+, event-handler attributes and +javascript:+ URLs — and Loofah
  # scrubs the contents of +style+ against its own CSS property allowlist.
  #
  # Merchants who embed videos can re-permit +iframe+ from an initializer:
  #
  #   Spree::RichTextSanitizer.allowed_tags += %w[iframe]
  #   Spree::RichTextSanitizer.allowed_attributes += %w[allowfullscreen frameborder]
  class RichTextSanitizer
    class_attribute :allowed_tags,
                    default: (Rails::HTML5::SafeListSanitizer.allowed_tags.to_a +
                              %w[table thead tbody tfoot tr th td]).uniq.freeze

    class_attribute :allowed_attributes,
                    default: (Rails::HTML5::SafeListSanitizer.allowed_attributes.to_a +
                              %w[style target rel colspan rowspan]).uniq.freeze

    # @param html [String, nil] rich text HTML
    # @return [String, nil] HTML with disallowed tags and attributes removed, or the input unchanged when blank
    def self.sanitize(html)
      return html if html.blank?

      Rails::HTML5::SafeListSanitizer.new.sanitize(
        html,
        tags: allowed_tags,
        attributes: allowed_attributes
      )
    end
  end
end
