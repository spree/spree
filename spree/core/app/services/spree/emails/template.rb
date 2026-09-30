module Spree
  module Emails
    # One Liquid email template on disk, with optional front matter.
    class Template
      FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m

      attr_reader :key, :path

      # @param key [String] the template key, e.g. "spree/order_mailer/confirm_email"
      # @param path [String] the file on disk
      def initialize(key:, path:)
        @key = key
        @path = path
      end

      # @return [String, nil] the subject line as Liquid, read from the front matter
      def subject
        front_matter['subject']
      end

      # @return [String] the template without its front matter
      def body
        source.sub(FRONT_MATTER, '')
      end

      private

      def source
        @source ||= File.read(path)
      end

      def front_matter
        @front_matter ||= begin
          match = source.match(FRONT_MATTER)
          match ? YAML.safe_load(match[1]).to_h : {}
        end
      end
    end
  end
end
