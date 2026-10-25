module Spree
  module Emails
    # One Liquid email template: a file on disk, with optional front matter
    # holding its subject, or a store's saved version with the subject in its
    # own field.
    class Template
      FRONT_MATTER = /\A---\s*\n(.*?)\n---\s*(?:\n|\z)/m

      attr_reader :key, :path

      # @param key [String] the template key, e.g. "spree/order_mailer/confirm_email"
      # @param path [String, nil] the file on disk
      # @param subject [String, nil] the subject, for a template not read from a file
      # @param body [String, nil] the body, for a template not read from a file
      def initialize(key:, path: nil, subject: nil, body: nil)
        @key = key
        @path = path
        @subject = subject
        @body = body
      end

      # @return [Boolean] whether this is a store's saved template or a draft, rather than a file
      def stored?
        path.nil?
      end

      # @return [String, nil] the subject line as Liquid
      def subject
        stored? ? @subject : front_matter['subject']
      end

      # @return [String] the template without its front matter
      def body
        stored? ? @body.to_s : source.sub(FRONT_MATTER, '')
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
