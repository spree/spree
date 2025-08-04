module Spree
  module Admin
    class FormBuilder < ActionView::Helpers::FormBuilder
      def error_message_on(method, options = {})
        @template.error_message_on(@object_name, method, objectify_options(options))
      end

      def spree_text_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.text_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def spree_number_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.number_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def spree_email_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.email_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def spree_date_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.date_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def spree_datetime_field(method, options = {})
        options[:class] ||= 'form-control'
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.datetime_field(@object_name, method, objectify_options(options)) +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

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

      def spree_rich_text_area(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.label(@object_name, method, get_label(method, options)) +
            @template.content_tag(:div, class: 'trix-container') do
              @template.rich_text_area(@object_name, method, objectify_options(options))
            end +
            @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

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

      def spree_check_box(method, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.content_tag(:div, class: 'custom-control custom-checkbox') do
            @template.check_box(@object_name, method, objectify_options(options.merge(class: 'custom-control-input'))) +
            @template.label(@object_name, method, get_label(method, options), class: 'custom-control-label')
          end + @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def spree_radio_button(method, tag_value, options = {})
        @template.content_tag(:div, class: 'form-group') do
          @template.content_tag(:div, class: 'custom-control custom-radio') do
            @template.radio_button(@object_name, method, tag_value, objectify_options(options.merge(class: 'custom-control-input'))) +
              @template.label(@object_name, method, get_label(method, options), class: 'custom-control-label', for: options[:id])
          end + @template.error_message_on(@object_name, method) + field_help(method, options)
        end
      end

      def field_help(_method, options = {})
        @template.content_tag(:span, options[:help], class: 'form-text text-muted mt-2')
      end

      private

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
