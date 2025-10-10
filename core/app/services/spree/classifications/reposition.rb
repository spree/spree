module Spree
  module Classifications
    class Reposition
      prepend Spree::ServiceModule::Base

      def call(classification:, position:)
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
