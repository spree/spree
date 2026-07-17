module Spree
  # Converts stored rich text HTML (Tiptap output persisted in plain text
  # columns, e.g. +Spree::Product#description+) into a faithful plain-text
  # rendering for API +description+/+body+ fields.
  #
  # Tiptap serializes blocks with no whitespace between them
  # (+<p>a</p><p>b</p>+), so a naive tag strip glues adjacent blocks into a
  # single run ("ab") and loses every paragraph and line break. This maps
  # block boundaries and +<br>+ to newlines before stripping tags, keeping the
  # text readable for storefronts, feeds, search indexing, and meta tags.
  #
  # Newlines already present in the markup (pretty-printed source from the
  # legacy admin's TinyMCE code view, imports, seeds) render as a single space
  # in a browser and are treated the same way here — only +<br>+ and block
  # boundaries produce line breaks.
  module RichTextHelper
    # Closing block tags whose boundaries become line breaks.
    BLOCK_BOUNDARY = %r{</(?:p|div|li|h[1-6]|blockquote|tr|ul|ol|table|section|article|header|footer|pre)>}i

    # Hard line breaks.
    LINE_BREAK = %r{<br\s*/?>}i

    # @param html [String, nil] rich text HTML
    # @return [String] plain text with paragraph and line breaks preserved
    def self.to_plain_text(html)
      return '' if html.blank?

      with_breaks = html.gsub(/\s+/, ' ').gsub(LINE_BREAK, "\n").gsub(BLOCK_BOUNDARY, "\\0\n")

      Nokogiri::HTML.fragment(with_breaks).text
                    .gsub(/[^\S\n]+/, ' ') # collapse runs of non-newline whitespace
                    .gsub(/ *\n */, "\n")  # trim spaces hugging newlines
                    .gsub(/\n{3,}/, "\n\n") # cap consecutive blank lines
                    .strip
    end
  end
end
