module Spree
  module Emails
    # Finds text an email would never show: MJML keeps text only inside
    # content components such as `<mj-text>` and `<mj-button>`, and renders
    # text written straight into a section, column or wrapper in a cell with
    # no font size. A template edited in the dashboard is checked, so the
    # merchant is told where the text went instead of seeing nothing change.
    class InvisibleTextCheck
      # Components whose children are laid out, not printed.
      CONTAINERS = %w[mj-body mj-wrapper mj-section mj-column mj-group mj-hero mj-accordion mj-accordion-element
                      mj-carousel mj-navbar mj-social].freeze

      TOKEN = %r{<(/?)(mj-[a-z-]+)\b[^>]*?(/?)>|<[^>]*>|[^<]+}m
      # Liquid that prints nothing: tags, and blocks whose content is not output.
      SILENT_BLOCKS = /\{%-?\s*(capture|comment|raw)\b.*?\{%-?\s*end\1\s*-?%\}/m
      SILENT = /\{%.*?%\}|\{\{.*?\}\}/m

      # @param source [String] a template body
      # @param top_level_shown [Boolean] whether text outside any component is
      #   inside the layout's wrapper (an email's body), rather than wherever a
      #   partial is rendered
      # @return [Array<Hash>] `{ line:, text: }` per piece of text that would not show
      def self.call(source, top_level_shown: true)
        new(source, top_level_shown).call
      end

      def initialize(source, top_level_shown)
        @source = blank_out(blank_out(source.to_s, SILENT_BLOCKS), SILENT)
        @top_level_shown = top_level_shown
      end

      def call
        stack = []
        problems = []

        @source.to_enum(:scan, TOKEN).each do
          match = Regexp.last_match
          closing, component, self_closing = match[1], match[2], match[3]

          if component
            next if self_closing.present?

            closing.present? ? stack.pop : stack.push(component)
          elsif !match[0].start_with?('<') && match[0].strip.present? && hidden?(stack)
            problems << { line: @source[0...match.begin(0)].count("\n") + 1 + match[0][/\A\s*/].count("\n"),
                          text: match[0].strip.truncate(40) }
          end
        end

        problems
      end

      private

      def hidden?(stack)
        stack.empty? ? @top_level_shown : CONTAINERS.include?(stack.last)
      end

      # Replaces matches with spaces, keeping line breaks so line numbers hold.
      def blank_out(text, pattern)
        text.gsub(pattern) { |match| match.gsub(/[^\n]/, ' ') }
      end
    end
  end
end
