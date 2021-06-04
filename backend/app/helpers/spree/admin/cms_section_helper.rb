module Spree
  module Admin
    module CmsSectionHelper
      def section_types_dropdown_values
        formatted_types = []

        Spree::CmsSection::TYPES.each do |type|
          last_word = type.split('::', 10).last
          readable_type = last_word.gsub(/(?<=[a-z])(?=[A-Z])/, ' ')
          formatted_types << [readable_type, type]
        end

        formatted_types
      end
    end
  end
end
