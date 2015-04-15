module Spree
  module Admin
    class Resource
      def initialize(controller_path, controller_name, parent_model, object_name = nil)
        @controller_path = controller_path
        @controller_name = controller_name
        @parent_model = parent_model
        @object_name = object_name
      end

      def sub_namespace_parts
        @controller_path.split('/')[2..-2]
      end

      def model_class
        sub_namespace = sub_namespace_parts.map { |s| s.capitalize }.join('::')
        sub_namespace = "#{sub_namespace}::" if sub_namespace.length > 0
        "Spree::#{sub_namespace}#{@controller_name.classify}".constantize
      end

      def model_name
        sub_namespace = sub_namespace_parts.join('/')
        sub_namespace = "#{sub_namespace}/" if sub_namespace.length > 0
        @parent_model.gsub("spree/#{sub_namespace}", '')
      end

      def object_name
        return @object_name if @object_name
        sub_namespace = sub_namespace_parts.join('_')
        sub_namespace = "#{sub_namespace}_" if sub_namespace.length > 0
        "#{sub_namespace}#{@controller_name.singularize}"
      end
    end
  end
end
