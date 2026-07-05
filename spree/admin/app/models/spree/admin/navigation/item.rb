module Spree
  module Admin
    class Navigation
      class Item
        attr_accessor :key, :label, :url, :icon, :position, :parent_key,
                      :condition, :badge, :badge_class, :tooltip, :target, :data_attributes, :children, :section_label, :active_condition

        def initialize(key, **options)
          @key = key.to_sym
          @label = options[:label]
          @url = options[:url]
          @icon = options[:icon]
          @position = options[:position] || 999
          @parent_key = options[:parent]
          @active_condition = options[:active]
          @condition = options.key?(:if) ? options[:if] : options[:condition]
          @badge = options[:badge]
          @badge_class = options[:badge_class]
          @tooltip = options[:tooltip]
          @target = options[:target]
          @data_attributes = options[:data_attributes] || {}
          @section_label = options[:section_label]
          @children = []
        end

        # Check if this item should be visible for the given user/context
        # @param user_or_context [Object] Either a user object or a view context
        def visible?(user_or_context = nil)
          return true if condition.nil?

          if condition.respond_to?(:call)
            # If we have a view context with instance_exec, use it to evaluate the condition
            # This allows access to can? and other helper methods
            if user_or_context.respond_to?(:instance_exec)
              user_or_context.instance_exec(&condition)
            else
              # Otherwise, call with the user object
              condition.call(user_or_context)
            end
          else
            condition
          end
        end

        # Check if this item is active based on current path
        # @param current_path [String] The current request path
        # @param context [Object] View context with access to route helpers
        def active?(current_path, context = nil)
          # Use custom active condition if provided (most flexible)
          if active_condition.respond_to?(:call)
            if context&.respond_to?(:instance_exec)
              return context.instance_exec(&active_condition)
            else
              return active_condition.call
            end
          end

          # Match exact path
          item_url = resolve_url(context)
          return true if item_url && current_path == item_url

          # Check if any child item is active
          return true if children.any? { |child| child.active?(current_path, context) }

          # Default: match if path starts with url (handled by active_link_to)
          if item_url
            current_path.start_with?(item_url)
          else
            false
          end
        end

        # Resolve URL (handles symbols, procs, and strings)
        # @param context [Object] View context with access to route helpers
        def resolve_url(context = nil)
          case url
          when Symbol
            # Try to call the route helper on the context (which has spree routes)
            if context&.respond_to?(url)
              context.send(url)
            elsif context&.respond_to?(:spree)
              context.spree.send(url) rescue url.to_s
            else
              url.to_s
            end
          when Proc
            # Evaluate proc in the context where route helpers are available
            if context&.respond_to?(:instance_exec)
              context.instance_exec(&url)
            else
              url.call
            end
          else
            url
          end
        end

        # Resolve label (handles i18n keys)
        def resolve_label
          return label unless label.is_a?(String) || label.is_a?(Symbol)

          # Use Spree.t for translation which handles the spree namespace
          Spree.t(label, default: label.to_s.humanize)
        end

        # Compute badge value
        # @param view_context [Object] View context with access to helper methods
        def badge_value(view_context = nil)
          return nil unless badge

          if badge.respond_to?(:call)
            # Evaluate badge in view context if available (for access to helpers)
            if view_context&.respond_to?(:instance_exec)
              view_context.instance_exec(&badge)
            else
              badge.call
            end
          else
            badge
          end
        end

        # Check if this is a section header
        def section?
          section_label.present?
        end

        # Add a child item
        def add_child(item)
          children << item
          item.parent_key = key
          sort_children!
        end

        # Remove a child item
        def remove_child(key)
          children.reject! { |child| child.key == key }
        end

        # Sort children by position
        def sort_children!
          children.sort_by! { |child| [child.position, child.key.to_s] }
        end

        # Deep clone for modifications
        def deep_clone
          cloned = self.class.new(key, to_h)
          cloned.children = children.map(&:deep_clone)
          cloned
        end

        # Convert to hash
        def to_h
          {
            label: label,
            url: url,
            icon: icon,
            position: position,
            parent: parent_key,
            active: active_condition,
            condition: condition,
            badge: badge,
            badge_class: badge_class,
            tooltip: tooltip,
            target: target,
            data_attributes: data_attributes,
            section_label: section_label
          }
        end

        def inspect
          "#<Spree::Admin::Navigation::Item key=#{key} label=#{label} children=#{children.size}>"
        end
      end
    end
  end
end
