module Spree
  module Core
    module EnvironmentExtension
      extend ActiveSupport::Concern

      def add_class(name)
        instance_variable_set "@#{name}", Set.new

        create_method("#{name}=".to_sym) do |val|
          instance_variable_set('@' + name, val)
        end

        create_method(name.to_sym) do
          instance_variable_get('@' + name)
        end
      end

      private

      def create_method(name, &block)
        self.class.send(:define_method, name, &block)
      end
    end
  end
end
