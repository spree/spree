module Spree
  module TestingSupport
    module Emails
      # The decoded text of every part of an email, HTML and plain text
      # together. Rendered emails are quoted-printable on the wire, so the raw
      # encoded body splits long lines and turns "=" into "=3D".
      #
      # @param message [Mail::Message, ActionMailer::MessageDelivery]
      # @return [String]
      def email_body(message)
        message = message.message if message.respond_to?(:message) && !message.is_a?(Mail::Message)
        parts = message.multipart? ? message.parts : [message]

        parts.map(&:decoded).join("\n")
      end
    end
  end
end

RSpec.configure do |config|
  config.include Spree::TestingSupport::Emails
end
