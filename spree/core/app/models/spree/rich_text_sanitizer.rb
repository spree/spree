# frozen_string_literal: true

module Spree
  # Allowlist sanitizer for rich text HTML stored in plain text columns
  # (e.g. +Spree::Product#description+).
  #
  # The allowlist is scoped to what the dashboard's editor actually emits —
  # Tiptap StarterKit plus Link. Anything outside that set is markup no writer
  # in Spree produces, so permitting it would only widen the attack surface
  # (inline styles for CSS overlays, +class+ for collisions with storefront
  # styles, +iframe+/+object+ for framed third-party content).
  #
  # Widening it is a deliberate act, not a default: an editor gaining a node
  # type widens the allowlist in the same change. Merchants whose legacy
  # descriptions embed richer markup — tables or video +iframe+s from the
  # pre-6.0 TinyMCE admin — can re-permit it from an initializer, and should,
  # because content is re-sanitized on its next save:
  #
  #   Spree::RichTextSanitizer.allowed_tags += %w[table thead tbody tr th td]
  #   Spree::RichTextSanitizer.allowed_attributes += %w[colspan rowspan]
  class RichTextSanitizer
    # Tiptap StarterKit (paragraph, headings, hard break, horizontal rule,
    # bold, italic, strike, underline, code, code block, blockquote, lists)
    # plus Link and Image. Verified against each extension's +renderHTML+.
    class_attribute :allowed_tags,
                    default: %w[
                      p br hr
                      h1 h2 h3 h4 h5 h6
                      strong em s u code pre
                      blockquote ul ol li a img
                    ].freeze

    # +href+/+target+/+rel+/+title+ come from Link; +src+/+alt+/+width+/+height+
    # from Image. +class+ is permitted only because a code block carries
    # +language-*+ on its inner +code+ element; the class scrubber below is what
    # keeps that from being a free-for-all.
    #
    # +src+ needs no protocol allowlist of its own: the permit scrubber drops an
    # attribute whose value carries an unsafe scheme, so +data:+ and
    # +javascript:+ URIs are stripped while https and relative URLs survive.
    class_attribute :allowed_attributes,
                    default: %w[href target rel title class src alt width height].freeze

    # Classes surviving on +code+ elements. Tiptap writes +language-<name>+
    # from its +languageClassPrefix+; nothing else in the editor emits a class,
    # so every other value is stripped rather than trusted.
    class_attribute :allowed_class_pattern, default: /\Alanguage-[a-z0-9+#-]+\z/i

    # Elements allowed to carry a class at all. Only the code block needs one,
    # and keeping the list tight stops +language-*+ from becoming a way to put a
    # class on arbitrary markup.
    class_attribute :classable_tags, default: %w[code].freeze

    # Tags whose *contents* are dropped along with the tag. Stripping only the
    # tag would leave the script body or stylesheet behind as visible text.
    class_attribute :pruned_tags, default: %w[script style].freeze

    # @param html [String, nil] rich text HTML
    # @return [String, nil] HTML with disallowed tags and attributes removed, or the input unchanged when blank
    def self.sanitize(html)
      return html if html.blank?

      # Both scrubbers run against a single parsed fragment. Going through
      # SafeListSanitizer twice (once to prune, once to allowlist) would parse
      # and re-serialize the whole document on every save.
      fragment = Loofah.html5_fragment(html)
      fragment.scrub!(prune_scrubber)
      fragment.scrub!(permit_scrubber)
      fragment.to_html
    end

    # Drops pruned elements subtree-and-all — allowlisting alone would strip the
    # tag but leave the script body or stylesheet behind as visible text — and
    # narrows +class+ to the code-block language hint in the same pass.
    def self.prune_scrubber
      tags = pruned_tags
      classable = classable_tags
      pattern = allowed_class_pattern

      Loofah::Scrubber.new(direction: :top_down) do |node|
        next node.remove if tags.include?(node.name)
        next unless node.element? && node.key?('class')
        next node.delete('class') unless classable.include?(node.name)

        kept = node['class'].split.select { |name| pattern.match?(name) }
        kept.empty? ? node.delete('class') : node['class'] = kept.join(' ')
      end
    end
    private_class_method :prune_scrubber

    def self.permit_scrubber
      Rails::HTML::PermitScrubber.new.tap do |scrubber|
        scrubber.tags = allowed_tags
        scrubber.attributes = allowed_attributes
      end
    end
    private_class_method :permit_scrubber
  end
end
