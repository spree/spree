# Ability to define partial injection points for Admin and Storefront
module Spree
  module Core
    class Partials
      def initialize(config, environment)
        @config = config
        @environment = environment
        define_dynamic_methods
      end

      attr_reader :config, :environment

      def partial_members
        environment.members.select { |member| member.to_s.end_with?('_partials') }
      end

      def keys
        partial_members.map { |member| member.to_s.sub(/_partials$/, '') }
      end

      private

      def define_dynamic_methods
        # Get all members that end with _partials from the Environment
        partial_members.each do |member|
          # Strip the _partials suffix for the method name
          method_name = member.to_s.sub(/_partials$/, '')

          # Define getter method on singleton class
          singleton_class.define_method(method_name) do
            config.send(member)
          end

          # Define setter method on singleton class
          singleton_class.define_method("#{method_name}=") do |value|
            config.send("#{member}=", value)
          end
        end
      end
    end
  end
end
