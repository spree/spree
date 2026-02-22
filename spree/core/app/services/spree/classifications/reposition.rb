module Spree
  module Classifications
    # @deprecated This service is deprecated and will be removed in Spree 5.5.
    class Reposition
      prepend Spree::ServiceModule::Base

      def call(classification:, position:)
        Spree::Deprecation.warn(
          "#{self.class.name} is deprecated and will be removed in Spree 5.5.",
          caller_locations(2)
        )
        if position.is_a?(String) && !position.match(/^\d+$/)
          return failure(nil, I18n.t('errors.messages.not_a_number'))
        end

        # Because position we get back is 0-indexed.
        # acts_as_list is 1-indexed.
        classification.insert_at(position.to_i + 1)
        success(classification)
      end
    end
  end
end
