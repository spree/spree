module Spree
  module Core
    module EnvironmentExtension
      extend ActiveSupport::Concern

      def add_class(name)
        ActiveSupport::Deprecation.warn(<<-EOS, caller)
          EnvironmentExtension module is deprecated and will be removed in Spree 3.6
        EOS
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
