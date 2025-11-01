module Spree
  module Admin
    module DropdownHelper
      def dropdown(options = {}, &block)
        options[:class] = ['dropdown'] + Array(options[:class])
        options[:data] = { controller: 'dropdown' }.merge(options[:data] || {})
        content_tag(:div, options, &block)
      end

      def dropdown_toggle(options = {}, &block)
        options[:type] = 'button'
        options[:class] = ['btn'] + Array(options[:class])
        options[:data] = { action: 'dropdown#toggle click@window->dropdown#hide' }.merge(options[:data] || {})
        button_tag(options, &block)
      end

      def dropdown_menu(options = {}, &block)
        options[:class] = ['dropdown-container hidden'] + Array(options[:class])

        if options[:direction] == 'left'
          options[:class] << 'dropdown-container-left'
        elsif options[:direction] == 'top'
          options[:class] << 'dropdown-container-top'
        elsif options[:direction] == 'top-left'
          options[:class] << 'dropdown-container-top dropdown-container-left'
        end
        options[:data] = { dropdown_target: 'menu' }.merge(options[:data] || {})
        content_tag(:div, options, &block)
      end
    end
  end
end
