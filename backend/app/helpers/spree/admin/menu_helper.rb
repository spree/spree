module Spree
  module Admin
    module MenuHelper
      def humanize_class_name(object)
        if object.is_a? Array
          object.map do |obj|
            obj.split('::').last
          end
        elsif object.is_a? String
          object.split('::').last
        else
          'Pass me a String or an Array'
        end
      end
    end
  end
end
