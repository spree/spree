module Spree
  module Preferences
    # Raised when a `preferences` payload does not match the schema its type
    # declares. Each failure names the value by a JSON pointer into the
    # payload, so a client can show it next to the field it belongs to.
    class InvalidPreferences < StandardError
      # @return [Array<Hash{Symbol => String}>] `{ pointer:, message: }` per failure
      attr_reader :failures

      # @param failures [Array<Hash{Symbol => String}>] pointers relative to the preferences object
      # @param prefix [String] where the preferences object sits in the request
      def initialize(failures, prefix: '/preferences')
        @failures = failures.map { |failure| failure.merge(pointer: "#{prefix}#{failure[:pointer]}") }
        super(@failures.map { |failure| "#{failure[:pointer]}: #{failure[:message]}" }.join('; '))
      end
    end
  end
end
