module Spree
  module ParameterizableName
    extend ActiveSupport::Concern

    included do
      normalizes :name, :presentation, with: ->(value) { value&.to_s&.squish&.presence }

      #
      # Callbacks
      #
      before_validation :set_name_from_presentation, if: -> { name.blank? }
      before_validation :normalize_name

      #
      # Scopes
      #
      scope :search_by_name, ->(query) do
        i18n do
          name.matches("%#{query.downcase}%").or(presentation.matches("%#{query.downcase}%"))
        end
      end

      def set_name_from_presentation
        self.name = presentation
      end

      def normalize_name
        self.name = name.to_s.parameterize.strip
      end
    end
  end
end
