module Spree
  module Backend
    module Callbacks
      extend ActiveSupport::Concern

      module ClassMethods

        attr_accessor :callbacks

        protected

        def new_action
          @callbacks ||= {}
          @callbacks[:new_action] ||= Spree::ActionCallbacks.new
        end

        def create
          @callbacks ||= {}
          @callbacks[:create] ||= Spree::ActionCallbacks.new
        end

        def update
          @callbacks ||= {}
          @callbacks[:update] ||= Spree::ActionCallbacks.new
        end

        def destroy
          @callbacks ||= {}
          @callbacks[:destroy] ||= Spree::ActionCallbacks.new
        end

        def custom_callback(action)
          @callbacks ||= {}
          @callbacks[action] ||= Spree::ActionCallbacks.new
        end
      end

      protected

      def invoke_callbacks(action, callback_type)
        callbacks = self.class.callbacks || {}
        return if callbacks[action].nil?
        case callback_type.to_sym
          when :before then callbacks[action].before_methods.each {|method| send method }
          when :after  then callbacks[action].after_methods.each  {|method| send method }
          when :fails  then callbacks[action].fails_methods.each  {|method| send method }
        end
      end

    end
  end
end
