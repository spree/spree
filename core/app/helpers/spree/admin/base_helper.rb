module Spree
  module Admin
    module BaseHelper
      def field_container(model, method, options = {}, &block)
        css_classes = options[:class].to_a
        css_classes << 'field'
        if error_message_on(model, method).present?
          css_classes << 'withError'
        end
        content_tag(:div, capture(&block), :class => css_classes.join(' '), :id => "#{model}_#{method}_field")
      end

      def error_message_on(object, method, options = {})
        object = convert_to_model(object)
        obj = object.respond_to?(:errors) ? object : instance_variable_get("@#{object}")

        if obj && obj.errors[method].present?
          errors = obj.errors[method].map { |err| h(err) }.join('<br />').html_safe
          content_tag(:span, errors, :class => 'formError')
        else
          ''
        end
      end

      # This method demonstrates the use of the :child_index option to render a
      # form partial for, for instance, client side addition of new nested
      # records.
      #
      # This specific example creates a link which uses javascript to add a new
      # form partial to the DOM.
      #
      #   <%= form_for @project do |project_form| %>
      #     <div id="tasks">
      #       <%= project_form.fields_for :tasks do |task_form| %>
      #         <%= render :partial => 'task', :locals => { :f => task_form } %>
      #       <% end %>
      #     </div>
      #   <% end %>
      def generate_html(form_builder, method, options = {})
        options[:object] ||= form_builder.object.class.reflect_on_association(method).klass.new
        options[:partial] ||= method.to_s.singularize
        options[:form_builder_local] ||= :f

        form_builder.fields_for(method, options[:object], :child_index => 'NEW_RECORD') do |f|
          render(:partial => options[:partial], :locals => { options[:form_builder_local] => f })
        end

      end

      def generate_template(form_builder, method, options = {})
        escape_javascript generate_html(form_builder, method, options)
      end

      def remove_nested(fields)
        out = ''
        out << fields.hidden_field(:_destroy) unless fields.object.new_record?
        out << (link_to icon('delete'), "#", :class => 'remove')
        out.html_safe
      end

      def preference_field_tag(name, value, options)
        case options[:type]
        when :integer
          text_field_tag(name, value, preference_field_options(options))
        when :boolean
          hidden_field_tag(name, 0) +
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
          { :size => 10,
            :class => 'input_integer' }
        when :boolean
          {}
        when :string
          { :size => 10,
            :class => 'input_string' }
        when :password
          { :size => 10,
            :class => 'password_string' }
        when :text
          { :rows => 15,
            :cols => 85 }
        else
          { :size => 10,
            :class => 'input_string' }
        end

        field_options.merge!({
          :readonly => options[:readonly],
          :disabled => options[:disabled],
          :size     => options[:size]
        })
      end

      def preference_fields(object, form)
        return unless object.respond_to?(:preferences)
        object.preferences.keys.map{ |key|

          form.label("preferred_#{key}", t(key) + ": ") +
            preference_field_for(form, "preferred_#{key}", :type => object.preference_type(key))

        }.join("<br />").html_safe
      end

      def product_picker_field(name, value)
        products = Product.with_ids(value.split(','))
        product_names = products.inject({}){|memo,item| memo[item.id] = item.name; memo}
        product_rules = products.collect{ |p| { :id => p.id, :name => p.name } }
        %(<input type="text" name="#{name}" value="#{value}" class="tokeninput products" data-names='#{product_names.to_json}' data-pre='#{product_rules.to_json}'/>).html_safe
      end

      def link_to_add_fields(name, target, options = {})
        name = '' if options[:no_text]
        css_classes = options[:class] ? options[:class] + " add_fields" : "add_fields"
        link_to icon('add') + name, 'javascript:', :data => { :target => target }, :class => css_classes
      end

      # renders hidden field and link to remove record using nested_attributes
      def link_to_remove_fields(name, f, options = {})
        name = '' if options[:no_text]
        options[:class] = '' unless options[:class]
        options[:class] += 'no-text with-tip' if options[:no_text]
        link_to_with_icon('icon-trash', name, '#', :class => "remove_fields #{options[:class]}") + f.hidden_field(:_destroy)
      end

      def spree_dom_id(record)
        dom_id(record, 'spree')
      end

      private
        def attribute_name_for(field_name)
          field_name.gsub(' ', '_').downcase
        end
    end
  end
end
