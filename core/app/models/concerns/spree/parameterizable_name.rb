module Spree
  module ParameterizableName
    extend ActiveSupport::Concern

    included do
      #
      # Callbacks
      #
      before_validation :set_name_from_presentation, if: -> { name.blank? }
      before_validation :normalize_name

      def set_name_from_presentation
        self.name = presentation
      end

      def normalize_name
        self.name = name.to_s.parameterize.strip
      end
    end
  end
end
