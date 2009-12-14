module Spree
  module ThemeSupport

    # Listener class used for views hooks.
    class HookListener
      include Singleton

      attr_accessor :hook_modifiers

      def initialize
        @hook_modifiers = []
      end

      def modifiers_for_hook(hook_name)
        hook_modifiers.select{|hm| hm.hook_name == hook_name}
      end


      # Replace contents of hook_name using supplied render args or string returned from block
      def self.replace(hook_name, options = {}, &block)
        add_hook_modifier(hook_name, :replace, options, &block)
      end

      # Insert before existing contents of hook_name using supplied render args or string returned from block
      def self.insert_before(hook_name, options = {}, &block)
        add_hook_modifier(hook_name, :insert_before, options, &block)
      end

      # Insert after existing contents of hook_name using supplied render args or string returned from block
      def self.insert_after(hook_name, options = {}, &block)
        add_hook_modifier(hook_name, :insert_after, options, &block)
      end

      # Clear contents of hook_name
      def self.remove(hook_name)
        add_hook_modifier(hook_name, :replace)
      end


      private

        def self.add_hook_modifier(hook_name, action, options = {}, &block)
          if block
            renderer = lambda do |template|
              template.instance_eval(&block)
            end
          else
            if options.empty?
              renderer = nil
            else
              renderer = lambda do |template|
                template.render(options)
              end
            end
          end
          instance.hook_modifiers << HookModifier.new(hook_name, action, renderer)
        end

    end

  end
end
