module Spree
  module Admin
    # Custom form builder for Spree admin interface
    #
    # This form builder provides helper methods for creating form fields with
    # consistent styling and behavior across the Spree admin interface. It includes
    # form groups, error handling, help text, and other features.
    class FormBuilder < ActionView::Helpers::FormBuilder
      # Display error messages for a specific field
      #
      # @param method [Symbol] the field name
      # @param options [Hash] additional options for the error message
      # @return [String] HTML string containing the error message
      def error_message_on(method, options = {})
        @template.error_message_on(@object_name, method, objectify_options(options))
      end

      # Create a text field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options including:
      #   - :class [String] CSS classes (defaults to 'form-control')
      #   - :label [String, Boolean] label text or false to hide label
      #   - :required [Boolean] whether field is required
      #   - :help [String] help text to display below the field
      #   - :help_bubble [String] help bubble text
      # @return [String] HTML string containing the complete form group
      def spree_text_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.text_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a number field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group
      def spree_number_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.number_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create an email field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group
      def spree_email_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.email_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a date field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group
      def spree_date_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.date_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a datetime field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group
      def spree_datetime_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.datetime_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a textarea with Spree form styling and auto-grow functionality
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options including:
      #   - :class [String] CSS classes (defaults to 'form-control')
      #   - :rows [Integer] number of rows (defaults to 5)
      #   - :data [Hash] data attributes (defaults to textarea-autogrow controller)
      #   - other options from {#spree_text_field}
      # @return [String] HTML string containing the complete form group
      def spree_text_area(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          options[:class] ||= 'form-control'
          options[:rows] ||= 5
          options[:data] ||= { controller: 'textarea-autogrow' }

          @template.label(@object_name, method, get_label(method, options)) +
            @template.text_area(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a rich text area (Trix editor) with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group with Trix editor
      def spree_rich_text_area(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.content_tag(:div, class: 'trix-container') do
              @template.rich_text_area(@object_name, method, objectify_options(options))
            end +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a select field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param choices [Array, nil] options for the select field
      # @param options [Hash] field options including:
      #   - :autocomplete [Boolean] whether to enable autocomplete functionality
      #   - other options from {#spree_text_field}
      # @param html_options [Hash] HTML options for the select element
      # @param block [Proc] optional block for generating options
      # @return [String] HTML string containing the complete form group
      def spree_select(method, choices = nil, options = {}, html_options = {}, &block)
        if options[:autocomplete]
          html_options[:data] ||= {}
          html_options[:data][:controller] ||= 'autocomplete-select'
        else
          html_options[:class] ||= 'custom-select'
        end

        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.select(@object_name, method, choices, objectify_options(options), html_options, &block) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a collection select field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param collection [Array] collection of objects for the select options
      # @param value_method [Symbol] method to call on each object for the option value
      # @param text_method [Symbol] method to call on each object for the option text
      # @param options [Hash] field options including:
      #   - :autocomplete [Boolean] whether to enable autocomplete functionality
      #   - other options from {#spree_text_field}
      # @param html_options [Hash] HTML options for the select element
      # @return [String] HTML string containing the complete form group
      def spree_collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        if options[:autocomplete]
          html_options[:data] ||= {}
          html_options[:data][:controller] ||= 'autocomplete-select'
        else
          html_options[:class] ||= 'custom-select'
        end

        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.collection_select(@object_name, method, collection, value_method, text_method, objectify_options(options), html_options) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a checkbox with Spree custom control styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group with custom checkbox
      def spree_check_box(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.content_tag(:div, class: 'custom-control custom-checkbox') do
            @template.check_box(@object_name, method, objectify_options(options.merge(class: 'custom-control-input'))) +
            @template.label(@object_name, method, get_label(method, options), class: 'custom-control-label')
          end + @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Create a radio button with Spree custom control styling
      #
      # @param method [Symbol] the field name
      # @param tag_value [String] the value for this radio button option
      # @param options [Hash] field options including:
      #   - :id [String] the HTML ID for the radio button
      #   - other options from {#spree_text_field}
      # @return [String] HTML string containing the complete form group with custom radio button
      def spree_radio_button(method, tag_value, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.content_tag(:div, class: 'custom-control custom-radio') do
            @template.radio_button(@object_name, method, tag_value, objectify_options(options.merge(class: 'custom-control-input'))) +
              @template.label(@object_name, method, get_label(method, options), class: 'custom-control-label', for: options[:id])
          end + @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      # Generate help text for a field
      #
      # @param _method [Symbol] the field name (unused but kept for consistency)
      # @param options [Hash] field options
      # @option options [String] :help help text to display
      # @return [String] HTML string containing the help text or empty string
      def field_help(_method, options = {})
        @template.content_tag(:span, options[:help], class: 'form-text mt-2')
      end

      private

      # Generate the label for a field with required indicator and help bubble
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options
      # @option options [String, Boolean] :label label text or false to hide label
      # @option options [Boolean] :required whether field is required
      # @option options [String] :help_bubble help bubble text
      # @return [String] HTML string containing the complete label
      def get_label(method, options)
        return '' if options[:label] == false

        translated_label = if options[:label]
                              options[:label]
                            elsif I18n.exists?("spree.#{method}")
                              I18n.t("spree.#{method}")
                            else
                              I18n.t("activerecord.attributes.spree/#{@object_name.to_s.underscore}.#{method}")
                            end

        required_label = options[:required] ? ' ' + @template.required_span_tag : ''

        help_bubble = options[:help_bubble] ? ' ' + @template.help_bubble(options[:help_bubble]) : ''

        @template.raw(translated_label + required_label + help_bubble)
      end
    end
  end
end
