module Spree
  module Admin
    module DropdownHelper
      def dropdown(options = {}, &block)
        options[:class] = ['dropdown'] + Array(options[:class])

        # Extract direction option for backward compatibility and convert to Floating UI placement
        placement = case options.delete(:direction)
        when 'left'
          'bottom-end'
        when 'top'
          'top-start'
        when 'top-left'
          'top-end'
        else
          options[:placement] || 'bottom-start'
        end

        placement = flip_placement_for_rtl(placement)

        # Extract portal option
        portal = options.delete(:portal)

        data_attrs = {
          controller: 'dropdown',
          dropdown_placement_value: placement
        }

        # Add portal value if explicitly set
        data_attrs[:dropdown_portal_value] = portal unless portal.nil?

        options[:data] = data_attrs.merge(options[:data] || {})
        content_tag(:div, options, &block)
      end

      def dropdown_toggle(options = {}, &block)
        options[:type] = 'button'
        options[:class] = ['btn'] + Array(options[:class])
        options[:data] = {
          action: 'dropdown#toggle click@window->dropdown#hide',
          dropdown_target: 'toggle'
        }.merge(options[:data] || {})
        button_tag(options, &block)
      end

      def dropdown_menu(options = {}, &block)
        options[:class] = ['dropdown-container hidden'] + Array(options[:class])
        options[:data] = {
          dropdown_target: 'menu'
        }.merge(options[:data] || {})

        content_tag(:div, options, &block)
      end

      def flip_placement_for_rtl(placement)
        return placement unless rtl_locale?

        case placement
        when 'bottom-start' then 'bottom-end'
        when 'bottom-end' then 'bottom-start'
        when 'top-start' then 'top-end'
        when 'top-end' then 'top-start'
        else placement
        end
      end
    end
  end
end
