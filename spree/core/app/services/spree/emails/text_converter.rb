module Spree
  module Emails
    # Turns a rendered email's HTML into its plain-text part, keeping each
    # link as "label (url)". Generating the text rather than writing it by
    # hand means it can never drift from the HTML.
    class TextConverter
      BLOCK_ELEMENTS = %w[p div h1 h2 h3 h4 h5 h6 table tr ul ol li section blockquote].freeze
      SKIPPED_ELEMENTS = %w[head style script title img].freeze
      HIDDEN_STYLE = /display\s*:\s*none/i

      # @param html [String]
      # @return [String]
      def self.call(html)
        new(html).call
      end

      def initialize(html)
        @document = Nokogiri::HTML(html)
      end

      # @return [String]
      def call
        output = +''
        walk(@document.at('body') || @document, output)

        output.lines.map { |line| line.squeeze(' ').strip }.join("\n").gsub(/\n{3,}/, "\n\n").strip + "\n"
      end

      private

      def walk(node, output)
        node.children.each do |child|
          if child.text?
            output << child.text.gsub(/\s+/, ' ')
          elsif child.element?
            element(child, output)
          end
        end
      end

      def element(node, output)
        name = node.name.downcase
        return if SKIPPED_ELEMENTS.include?(name) || node['style'].to_s.match?(HIDDEN_STYLE)

        case name
        when 'br' then output << "\n"
        when 'a' then link(node, output)
        when 'td', 'th'
          walk(node, output)
          output << ' '
        else
          block = BLOCK_ELEMENTS.include?(name)
          output << "\n" if block
          walk(node, output)
          output << "\n" if block
        end
      end

      def link(node, output)
        label = +''
        walk(node, label)
        label = label.squeeze(' ').strip
        href = node['href'].to_s.strip.delete_prefix('mailto:')

        # A link with no text is a linked image, which has nothing to say in text.
        return if label.blank?

        output << (href.blank? || href == label ? label : "#{label} (#{href})")
      end
    end
  end
end
