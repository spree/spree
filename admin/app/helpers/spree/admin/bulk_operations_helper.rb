module Spree
  module Admin
    module BulkOperationsHelper
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

      def bulk_action_link(text, path, options = {})
        options[:data] ||= {}
        options[:data][:action] ||= 'click->bulk-operation#setBulkAction'
        options[:data][:turbo_frame] ||= :bulk_modal
        options[:data][:url] ||= options[:url]
        options[:class] ||= 'btn btn-light'

        if options[:icon]
          text = icon(options[:icon]) + ' ' + text
        end

        content_tag :span, data: { toggle: 'modal', target: '#bulk-modal' } do
          link_to text, path, options
        end
      end

      def bulk_operations_close_button
        button_tag(
          '', 
          type: 'button', 
          class: 'btn-close', 
          data: { 
            dismiss: 'modal', 
            aria_label: Spree.t(:close), 
            action: 'bulk-operation#cancel' 
          }
        )
      end

      def bulk_operations_counter
        content_tag(:span, class: 'bulk-operations-counter ml-1') do
          content_tag(:strong, '', data: { bulk_operation_target: 'counter' }) +
          Spree.t("admin.selected")
        end
      end
    end
  end
end
