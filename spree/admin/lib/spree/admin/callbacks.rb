require_relative 'action_callbacks'

module Spree
  module Admin
    module Callbacks
      extend ActiveSupport::Concern

      module ClassMethods
        attr_accessor :callbacks

        def new_action
          custom_callback(:new_action)
        end

        def edit_action
          custom_callback(:edit_action)
        end

        def create
          custom_callback(:create)
        end

        def update
          custom_callback(:update)
        end

        def destroy
          custom_callback(:destroy)
        end

        def custom_callback(action)
          @callbacks ||= {}
          @callbacks[action] ||= Spree::Admin::ActionCallbacks.new
        end
      end

      protected

      def invoke_callbacks(action, callback_type)
        callbacks = self.class.callbacks || {}
        return if callbacks[action].nil?

        case callback_type.to_sym
        when :before then callbacks[action].before_methods.each { |method| send method }
        when :after  then callbacks[action].after_methods.each  { |method| send method }
        when :fails  then callbacks[action].fails_methods.each  { |method| send method }
        end
      end
    end
  end
end
