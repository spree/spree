module Spree
  module Admin
    class Navigation
      class << self
        # Store registries for different contexts
        def registries
          @registries ||= {}
        end

        # Get or create a registry for a context
        def registry(context = :sidebar)
          registries[context.to_sym] ||= Registry.new(context.to_sym)
        end

        # Configure navigation for a specific context
        def configure(context = :sidebar, &block)
          reg = registry(context)
          builder = Builder.new(reg)
          # Support both block styles: |nav| nav.add or just add
          if block_given?
            if block.arity > 0
              # Block expects parameter: do |nav| nav.add ... end
              block.call(builder)
            else
              # Block uses implicit self: do add ... end
              builder.instance_eval(&block)
            end
          end
          reg
        end

        # Get a registry for method chaining
        def for(context)
          registry(context)
        end

        # Delegate common methods to the default (sidebar) registry
        def add(key, **options, &block)
          registry(:sidebar).add(key, **options, &block)
        end

        def remove(key)
          registry(:sidebar).remove(key)
        end

        def update(key, **options)
          registry(:sidebar).update(key, **options)
        end

        def find(key)
          registry(:sidebar).find(key)
        end

        def exists?(key)
          registry(:sidebar).exists?(key)
        end

        def insert_before(target_key, new_key, **options)
          registry(:sidebar).insert_before(target_key, new_key, **options)
        end

        def insert_after(target_key, new_key, **options)
          registry(:sidebar).insert_after(target_key, new_key, **options)
        end

        def move(key, **position_options)
          registry(:sidebar).move(key, **position_options)
        end

        def replace(key, **options, &block)
          registry(:sidebar).replace(key, **options, &block)
        end

        def visible_items(context = :sidebar, user = nil)
          registry(context).visible_items(user)
        end

        def root_items(context = :sidebar)
          registry(context).root_items
        end

        def breadcrumbs_for(current_path, context = :sidebar, view_context = nil)
          registry(context).breadcrumbs_for(current_path, view_context)
        end

        def find_active_item(current_path, context = :sidebar, view_context = nil)
          registry(context).find_active_item(current_path, view_context)
        end

        # Get all available contexts
        def contexts
          registries.keys
        end

        # Clear all registries (useful for testing)
        def clear_all!
          @registries = {}
        end

        # Clear a specific context
        def clear!(context = :sidebar)
          registry(context).clear
        end
      end
    end
  end
end

# Require the sub-classes
require_relative 'navigation/item'
require_relative 'navigation/registry'
require_relative 'navigation/builder'
