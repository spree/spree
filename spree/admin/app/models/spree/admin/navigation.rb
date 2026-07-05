module Spree
  module Admin
    class Navigation
      attr_reader :items, :context

      def initialize(context)
        @context = context
        @items = {}
      end

      # Add a navigation item
      def add(key, **options, &block)
        key = key.to_sym
        item = Item.new(key, **options)

        @items[key] = item

        # If block provided, it's for children
        if block_given?
          builder = Builder.new(self, item)
          # Support both block styles: |nav| nav.add or just add
          if block.arity > 0
            # Block expects parameter: do |nav| nav.add ... end
            block.call(builder)
          else
            # Block uses implicit self: do add ... end
            builder.instance_eval(&block)
          end
        end

        sort_items!
        item
      end

      # Remove a navigation item
      def remove(key)
        key = key.to_sym
        removed = @items.delete(key)

        # Also remove from any parent's children
        @items.each_value do |item|
          item.remove_child(key)
        end

        removed
      end

      # Update an existing navigation item
      def update(key, **options)
        key = key.to_sym
        item = @items[key]

        return nil unless item

        options.each do |attr, value|
          item.send("#{attr}=", value) if item.respond_to?("#{attr}=")
        end

        sort_items!
        item
      end

      # Find a navigation item
      def find(key)
        @items[key.to_sym]
      end

      # Check if item exists
      def exists?(key)
        @items.key?(key.to_sym)
      end

      # Insert item before another item
      def insert_before(target_key, new_key, **options)
        target = find(target_key)
        return nil unless target

        new_position = target.position - 1
        add(new_key, **options.merge(position: new_position))
      end

      # Insert item after another item
      def insert_after(target_key, new_key, **options)
        target = find(target_key)
        return nil unless target

        new_position = target.position + 1
        add(new_key, **options.merge(position: new_position))
      end

      # Move item to a new position
      def move(key, position: nil, before: nil, after: nil)
        item = find(key)
        return nil unless item

        if before
          target = find(before)
          item.position = target.position - 1 if target
        elsif after
          target = find(after)
          item.position = target.position + 1 if target
        elsif position == :first
          item.position = -999
        elsif position == :last
          item.position = 999
        elsif position.is_a?(Integer)
          item.position = position
        end

        sort_items!
        item
      end

      # Replace an item
      def replace(key, **options, &block)
        remove(key)
        add(key, **options, &block)
      end

      # Get all root items (items without a parent)
      def root_items
        @items.values.select { |item| item.parent_key.nil? }.sort_by { |item| [item.position, item.key.to_s] }
      end

      # Get all items that are visible to the user
      def visible_items(user = nil, parent_key = nil)
        items_to_filter = if parent_key
                            find(parent_key)&.children || []
                          else
                            root_items
                          end

        items_to_filter.select { |item| item.visible?(user) }
      end

      # Build tree structure
      def build_tree
        # First, clear all children
        @items.each_value { |item| item.children.clear }

        # Then rebuild the tree
        @items.each_value do |item|
          if item.parent_key && (parent = @items[item.parent_key])
            parent.add_child(item)
          end
        end

        root_items
      end

      # Clear all items
      def clear
        @items.clear
      end

      # Get all registered paths (for settings_area? detection)
      def registered_paths(context = nil)
        @items.values.map { |item| item.resolve_url(context) }.compact
      end

      # Add a section
      def section(key, label: nil, &block)
        # Create a section header item
        section_item = add(key, section_label: label || key.to_s.humanize, position: @items.size * 100)

        if block_given?
          builder = Builder.new(self, section_item)
          builder.instance_eval(&block)
        end

        section_item
      end

      # Deep clone the registry
      def deep_clone
        cloned = self.class.new(context)
        @items.each do |key, item|
          cloned.items[key] = item.deep_clone
        end
        cloned.build_tree
        cloned
      end

      private

      def sort_items!
        # Sort items by position, then rebuild tree
        @items = @items.sort_by { |_key, item| [item.position, item.key.to_s] }.to_h
        build_tree
      end
    end
  end
end
