module Spree
  module Admin
    module BaseHelper
      def flash_alert(flash)
        if flash.present?
          close_button = button_tag(class: 'close', 'data-dismiss' => 'alert', 'aria-label' => Spree.t(:close)) do
            content_tag('span', '&times;'.html_safe, 'aria-hidden' => true)
          end
          message = flash[:error] || flash[:notice] || flash[:success]
          flash_class = 'danger' if flash[:error]
          flash_class = 'info' if flash[:notice]
          flash_class = 'success' if flash[:success]
          flash_div = content_tag(:div, (close_button + message), class: "alert alert-#{flash_class} alert-auto-disappear")
          content_tag(:div, flash_div, class: 'col-12')
        end
      end

      def field_container(model, method, options = {}, &block)
        css_classes = options[:class].to_a
        css_classes << 'field'
        css_classes << 'withError' if error_message_on(model, method).present?
        content_tag(
          :div, capture(&block),
          options.merge(class: css_classes.join(' '), id: "#{model}_#{method}_field")
        )
      end

      def error_message_on(object, method, _options = {})
        object = convert_to_model(object)
        obj = object.respond_to?(:errors) ? object : instance_variable_get("@#{object}")

        if obj && obj.errors[method].present?
          errors = safe_join(obj.errors[method], '<br />'.html_safe)
          content_tag(:span, errors, class: 'formError')
        else
          ''
        end
      end

      def datepicker_field_value(date)
        unless date.blank?
          l(date, format: Spree.t('date_picker.format', default: '%Y/%m/%d'))
        end
      end

      def preference_field_tag(name, value, options)
        case options[:type]
        when :integer
          text_field_tag(name, value, preference_field_options(options))
        when :boolean
          hidden_field_tag(name, 0, id: "#{name}_hidden") +
            check_box_tag(name, 1, value, preference_field_options(options))
        when :string
          text_field_tag(name, value, preference_field_options(options))
        when :password
          password_field_tag(name, value, preference_field_options(options))
        when :text
          text_area_tag(name, value, preference_field_options(options))
        else
          text_field_tag(name, value, preference_field_options(options))
        end
      end

      def preference_field_for(form, field, options)
        case options[:type]
        when :integer
          form.text_field(field, preference_field_options(options))
        when :boolean
          form.check_box(field, preference_field_options(options))
        when :string
          form.text_field(field, preference_field_options(options))
        when :password
          form.password_field(field, preference_field_options(options))
        when :text
          form.text_area(field, preference_field_options(options))
        else
          form.text_field(field, preference_field_options(options))
        end
      end

      def preference_field_options(options)
        field_options = case options[:type]
                        when :integer
                          {
                            size: 10,
                            class: 'input_integer form-control'
                          }
                        when :boolean
                          {}
                        when :string
                          {
                            size: 10,
                            class: 'input_string form-control'
                          }
                        when :password
                          {
                            size: 10,
                            class: 'password_string form-control'
                          }
                        when :text
                          {
                            rows: 15,
                            cols: 85,
                            class: 'form-control'
                          }
                        else
                          {
                            size: 10,
                            class: 'input_string form-control'
                          }
                        end

        field_options.merge!(readonly: options[:readonly],
                             disabled: options[:disabled],
                             size: options[:size])
      end

      def preference_fields(object, form)
        return unless object.respond_to?(:preferences)

        fields = object.preferences.keys.map do |key|
          if object.has_preference?(key)
            form.label("preferred_#{key}", Spree.t(key) + ': ') +
              preference_field_for(form, "preferred_#{key}", type: object.preference_type(key))
          end
        end
        safe_join(fields, '<br />'.html_safe)
      end

      # renders hidden field and link to remove record using nested_attributes
      def link_to_icon_remove_fields(form)
        url = form.object.persisted? ? [:admin, form.object] : '#'
        link_to_with_icon('delete', '', url,
                          class: 'spree_remove_fields btn btn-sm btn-danger',
                          data: {
                            action: 'remove'
                          },
                          title: Spree.t(:remove),
                          no_text: true
                         ) + form.hidden_field(:_destroy)
      end

      def spree_dom_id(record)
        dom_id(record, 'spree')
      end

      I18N_PLURAL_MANY_COUNT = 2.1
      def plural_resource_name(resource_class)
        resource_class.model_name.human(count: I18N_PLURAL_MANY_COUNT)
      end

      def order_time(time)
        [I18n.l(time.to_date), time.strftime('%l:%M %p').strip].join(' ')
      end

      def required_span_tag
        content_tag(:span, ' *', class: 'required')
      end
    end
  end
end
