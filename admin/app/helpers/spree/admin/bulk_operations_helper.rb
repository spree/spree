module Spree
  module Admin
    module BulkOperationsHelper
      # render a checkbox to select all items for bulk operations
      # @return [String]
      def bulk_operations_select_all_checkbox
        content_tag :div, class: "custom-control custom-checkbox ml-1" do
          check_box_tag(
            nil,
            nil,
            false,
            id: "checkAllMasterCheckbox",
            class: "custom-control-input",
            data: { bulk_operation_target: "checkboxAll" }
          ) +
          content_tag(:label, content_tag(:span, ""), class: "custom-control-label", for: "checkAllMasterCheckbox")
        end
      end

      # render a checkbox to select an item for bulk operations
      # @param object [Spree::Product, Spree::User, Spree::Order]
      # @return [String]
      def bulk_operations_checkbox(object)
        content_tag :div, class: "custom-control custom-checkbox ml-1" do
          check_box_tag(
            "ids[]",
            object.id,
            false,
            class: "custom-control-input",
            id: "ids_#{object.id}",
            data: { bulk_operation_target: "checkbox" }
          ) +
          content_tag(:label, content_tag(:span, ""), class: "custom-control-label", for: "ids_#{object.id}")
        end
      end

      # render a link to perform a bulk action
      # @param text [String] the text of the link
      # @param path [String] the path of the link
      # @param options [Hash] the options of the link
      # @option options [String] :icon the icon of the link
      # @option options [String] :url the url to perform the bulk action to be set for the form in bulk modal
      # @option options [String] :class the class of the link
      # @option options [String] :data the data of the link
      # @return [String]
      def bulk_action_link(text, path, options = {})
        options[:data] ||= {}
        options[:data][:action] ||= 'click->bulk-operation#setBulkAction click->bulk-dialog#open'
        options[:data][:turbo_frame] ||= :bulk_dialog
        options[:data][:url] ||= options[:url]
        options[:class] ||= 'btn'

        tooltip_text = nil
        if options[:icon]
          if options[:only_icon]
            tooltip_text = options[:title] || text
            text = icon(options[:icon], class: 'mr-0')
            options[:data][:controller] = 'tooltip'
            options.delete(:title)
          else
            text = icon(options[:icon]) + ' ' + text
          end
        end

        link_content = text
        link_content += tooltip(tooltip_text) if tooltip_text

        link_to link_content, path, options
      end

      # render a close button for the bulk modal
      def bulk_operations_close_button
        button_tag(
          '',
          type: 'button',
          class: 'btn-close mr-1',
          data: {
            action: 'bulk-operation#cancel',
            aria_label: Spree.t(:close)
          }
        )
      end

      # render a counter for the bulk operations
      # @return [String]
      def bulk_operations_counter
        content_tag(:div, class: 'bulk-operations-counter') do
          content_tag(:span, class: 'bulk-operations-counter-label') do
            content_tag(:strong, '', data: { bulk_operation_target: 'counter' }) +
            Spree.t("admin.selected")
          end
        end
      end
    end
  end
end
