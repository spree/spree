module Spree
  module ImportService
    class Error < StandardError
      attr_reader :message, :identifier

      def initialize(identifier:, message:)
        @identifier = identifier
        @message = message
      end

      def to_h
        {
          identifier => message
        }
      end

      private
    end
  end
end