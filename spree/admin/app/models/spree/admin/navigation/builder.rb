module Spree
  module Admin
    class Navigation
      class Builder
        attr_reader :registry, :parent_item

        def initialize(registry, parent_item = nil)
          @registry = registry
          @parent_item = parent_item
        end

        # Add a navigation item
        # If parent_item is set, the item becomes a child
        def add(key, **options, &block)
          # If we have a parent item, set it in the options
          if parent_item
            options[:parent] = parent_item.key
            # Adjust position to be relative to parent
            options[:position] ||= parent_item.children.size * 10
          end

          item = registry.add(key, **options, &block)
          item
        end

        # Add a section (group of items)
        def section(key, label: nil, &block)
          section_item = add(key, section_label: label || key.to_s.humanize)

          if block_given?
            builder = self.class.new(registry, section_item)
            # Support both block styles: |nav| nav.add or just add
            if block.arity > 0
              # Block expects parameter: do |nav| nav.add ... end
              block.call(builder)
            else
              # Block uses implicit self: do add ... end
              builder.instance_eval(&block)
            end
          end

          section_item
        end

        # Remove an item
        def remove(key)
          registry.remove(key)
        end

        # Update an item
        def update(key, **options)
          registry.update(key, **options)
        end

        # Insert before another item
        def insert_before(target_key, new_key, **options)
          registry.insert_before(target_key, new_key, **options)
        end

        # Insert after another item
        def insert_after(target_key, new_key, **options)
          registry.insert_after(target_key, new_key, **options)
        end

        # Move an item
        def move(key, **position_options)
          registry.move(key, **position_options)
        end

        # Replace an item
        def replace(key, **options, &block)
          registry.replace(key, **options, &block)
        end

        # Reorder items with a block
        def reorder(&block)
          instance_eval(&block) if block_given?
        end
      end
    end
  end
end
