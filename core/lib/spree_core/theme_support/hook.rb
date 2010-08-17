module Spree
  module ThemeSupport
    module Hook

      @@listener_classes = []
      @@listeners = nil
      @@hook_modifiers = {}

      class << self
        # Adds a listener class.
        # Automatically called when a class inherits from Spree::ThemeSupport::HookListener.
        def add_listener(klass)
          raise "Hooks must include Singleton module." unless klass.included_modules.include?(Singleton)
          @@listener_classes << klass
          clear_listeners_instances
        end

        # Returns all the listerners instances.
        def listeners
          @@listeners ||= @@listener_classes.uniq.collect {|listener| listener.instance}
        end

        # Clears all the listeners.
        def clear_listeners
          @@listener_classes = []
          clear_listeners_instances
        end

        # Clears all the listeners instances.
        def clear_listeners_instances
          @@listeners = nil
          @@hook_modifiers = {}
        end

        # Take the content captured with a hook helper and modify with each HookModifier
        def render_hook(hook_name, content, context, locals = {})
          modifiers_for_hook(hook_name).inject(content) { |result, modifier| modifier.apply_to(result, context, locals) }
        end
        
        # All the HookModifier instances that are associated with this hook_name in extension load order and order they were defined
        def modifiers_for_hook(hook_name)
          @@hook_modifiers[hook_name] ||= listeners.map {|l| l.modifiers_for_hook(hook_name)}.flatten
        end

      end

    end
  end
end


