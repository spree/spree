module Spree
  module Emails
    # The finished parts of one email, ready for Action Mailer.
    class RenderedEmail
      attr_reader :subject, :html, :text

      def initialize(subject:, html:, text:)
        @subject = subject
        @html = html
        @text = text
      end
    end
  end
end
