module Spree
  module ThemeSupport

    # A hook modifier is created for each usage of 'insert_before','replace' etc.
    # This stores how the original contents of the hook should be modified
    # and does the work of altering the hooks content appropriately
    class HookModifier
      attr_accessor :hook_name
      attr_accessor :action
      attr_accessor :renderer

      def initialize(hook_name, action, renderer = nil)
        @hook_name = hook_name
        @action = action
        @renderer = renderer
      end

      def apply_to(content, context)
        return '' if renderer.nil?
        case action
        when :insert_before
          "#{renderer.call(context)}#{content}"
        when :insert_after
          "#{content}#{renderer.call(context)}"
        when :replace
          renderer.call(context).to_s
        else
          ''
        end
      end

    end

  end
end
