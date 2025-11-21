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
      #   - :prepend [String] text to prepend before the input field
      #   - :append [String] text to append after the input field
      # @return [String] HTML string containing the complete form group
      def spree_text_field(method, options = {})
        options[:class] ||= 'form-control'
        prepend = options.delete(:prepend)
        append = options.delete(:append)

        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            wrap_with_input_group(@template.text_field(@object_name, method, objectify_options(options)), prepend, append) +
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
        end
      end

      # Create a number field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options (see {#spree_text_field} for available options)
      # @return [String] HTML string containing the complete form group
      def spree_number_field(method, options = {})
        options[:class] ||= 'form-control'
        prepend = options.delete(:prepend)
        append = options.delete(:append)

        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            wrap_with_input_group(@template.number_field(@object_name, method, objectify_options(options)), prepend, append) +
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
            @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
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
          end + @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge!(class: 'form-text mt-2 ml-4'))
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
          end + @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
        end
      end

      # Create a direct file upload field with Spree form styling
      #
      # @param method [Symbol] the field name
      # @param options [Hash] field options
      # @option options [Boolean] :crop whether to crop the image
      # @option options [Boolean] :auto_submit whether to auto-submit the form when the file is uploaded
      # @option options [Boolean] :can_delete whether to show the delete button
      # @option options [Boolean] :inline whether to display the uploader inline
      # @option options [Integer] :height the height of the uploader
      # @option options [Integer] :width the width of the uploader
      # @option options [Array] :allowed_file_types the allowed file types, defaults to image types
      # @return [String] HTML string containing the complete form group with direct file upload field
      def spree_file_field(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
          @template.render('active_storage/upload_form', form: self, field_name: method, **options) +
          @template.error_message_on(@object_name, method) + spree_field_help(method, options.merge(class: 'form-text mt-2'))
        end
      end

      private

      # Generate help text for a field
      #
      # @param _method [Symbol] the field name (unused but kept for consistency)
      # @param options [Hash] field options
      # @option options [String] :help help text to display
      # @return [String] HTML string containing the help text or empty string
      def spree_field_help(_method, options = {})
        options[:class] ||= 'form-text mt-2'
        @template.content_tag(:span, options[:help], class: options[:class])
      end

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

      # Wrap a field with an input group if prepend or append is specified
      #
      # @param field_html [String] the HTML for the field
      # @param prepend [String, nil] text to prepend before the input field
      # @param append [String, nil] text to append after the input field
      # @return [String] HTML string with input group wrapper or the original field
      def wrap_with_input_group(field_html, prepend = nil, append = nil)
        return field_html if prepend.nil? && append.nil?

        @template.content_tag(:div, class: 'input-group') do
          prepend_html = if prepend.present?
                           @template.content_tag(:div, class: 'input-group-prepend') do
                             @template.content_tag(:span, prepend, class: 'input-group-text')
                           end
                         else
                           ''.html_safe
                         end

          append_html = if append.present?
                          @template.content_tag(:div, class: 'input-group-append') do
                            @template.content_tag(:span, append, class: 'input-group-text')
                          end
                        else
                          ''.html_safe
                        end

          prepend_html + field_html + append_html
        end
      end
    end
  end
end
