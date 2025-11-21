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
          builder.instance_eval(&block) if block_given?
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

        # Copy items from one context to another
        def copy_from(source_context, target_context, only: nil)
          source = registry(source_context)
          target = registry(target_context)

          items_to_copy = if only
                            only.map { |key| source.find(key) }.compact
                          else
                            source.root_items
                          end

          items_to_copy.each do |item|
            target.add(item.key, **item.to_h)
          end
        end

        # Merge items from one context into another
        def merge_from(source_context, target_context = :sidebar)
          copy_from(source_context, target_context)
        end
      end
    end
  end
end

# Require the sub-classes
require_relative 'navigation/item'
require_relative 'navigation/registry'
require_relative 'navigation/builder'
