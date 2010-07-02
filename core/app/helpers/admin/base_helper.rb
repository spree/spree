module Admin::BaseHelper

  # receives a :controller, :action, and :params.  Finds the given controller and runs user_authorized_for? on it.
  # This can be called in your views, and is for advanced users only.  If you are using :if / :unless eval expressions,
  #   then this may or may not work (eval strings use the current binding to execute, not the binding of the target
  #   controller)
  def url_options_authenticate?(params = {})
    params = params.symbolize_keys
    if params[:controller]
      # find the controller class
      klass = eval("#{params[:controller]}_controller".classify)
    else
      klass = self.class
    end
    klass.user_authorized_for?(current_user, params, binding)
  end

  def field_container(model, method, options = {}, &block)
    unless error_message_on(model, method).blank?
      css_class = 'withError'
    end
    html = content_tag('p', capture(&block), :class => css_class)
    concat(html)
  end

  def class_for_error(model, method)
    if error_message_on :product, :name
    end
  end
  
  #You can add additional_fields to the product and variant models. See section 4.2 here: http://spreecommerce.com/documentation/extensions.html 
  #If you do choose to add additional_fields, you can utilize the :use parameter to set the input type for any such fields. For example, :use => 'check_box'
  #In the event that you add this functionality, the following method takes care of rendering the proper input type and logic for the supported input-types, which are text_field, check_box, radio_button, and select.
  def get_additional_field_value(controller, field)
    attribute = attribute_name_for(field[:name])

    value = eval("@" + controller.controller_name.singularize + "." + attribute)

    if value.nil? && controller.controller_name == "variants"
      value = @variant.product.has_attribute?(attribute) ? @variant.product[attribute] : nil
    end

    if value.nil?
      return value
    else
      return field.key?(:format) ? sprintf(field[:format], value) : value
    end
  end

  # This method demonstrates the use of the :child_index option to render a
  # form partial for, for instance, client side addition of new nested
  # records.
  #
  # This specific example creates a link which uses javascript to add a new
  # form partial to the DOM.
  #
  #   <%= form_for @project do |project_form| -%>
  #     <div id="tasks">
  #       <% project_form.fields_for :tasks do |task_form| %>
  #         <%= render :partial => 'task', :locals => { :f => task_form } %>
  #       <% end %>
  #     </div>
  #   <% end -%>
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
    out << (link_to icon("delete"), "#", :class => "remove")
    out
  end

  def preference_field(form, field, options)
    case options[:type]
    when :integer
      form.text_field(field, {
          :size => 10,
          :class => 'input_integer',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :boolean
      form.check_box(field, {:readonly => options[:readonly],
          :disabled => options[:disabled]})
    when :string
      form.text_field(field, {
          :size => 10,
          :class => 'input_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :password
      form.password_field(field, {
          :size => 10,
          :class => 'password_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    when :text
      form.text_area(field,
        {:rows => 15, :cols => 85, :readonly => options[:readonly],
          :disabled => options[:disabled]}
      )
    else
      form.text_field(field, {
          :size => 10,
          :class => 'input_string',
          :readonly => options[:readonly],
          :disabled => options[:disabled]
        }
      )
    end
  end

  def preference_fields(object, form)
    return unless object.respond_to?(:preferences)
    object.preferences.keys.map{ |key|
      next unless object.class.preference_definitions.has_key? key

      definition = object.class.preference_definitions[key]
      type = definition.instance_eval{@type}.to_sym

      form.label("preferred_#{key}", t(key)+": ") +
        preference_field(form, "preferred_#{key}", :type => type)
    }.join("<br />")
  end

  def additional_field_for(controller, field)
     field[:use] ||= 'text_field'
     options = field[:options] || {}

     object_name, method = controller.controller_name.singularize, attribute_name_for(field[:name])

     case field[:use]
     when 'check_box'
       check_box(object_name, method, options, field[:checked_value] || 1, field[:unchecked_value] || 0)
     when 'radio_button'
       html = ''
       field[:value].call(controller, field).each do |value|
         html << radio_button(object_name, method, value, options)
         html << " #{value.to_s} "
       end
       html
     when 'select'
       select(object_name, method, field[:value].call(controller, field), options, field[:html_options] || {})
     else
       value = field[:value] ? field[:value].call(controller, field) : get_additional_field_value(controller, field)
       __send__(field[:use], object_name, method, options.merge(:value => value))
     end # case
   end

  def product_picker_field(name, value)
    products = Product.with_ids(value)
    product_names_hash = products.inject({}){|memo,item| memo[item.id] = item.name; memo}
    %(<input type="text" name="#{name}" value="#{value}" class="tokeninput products" data-names='#{product_names_hash.to_json}' />)
  end

  private
  def attribute_name_for(field_name)
    field_name.gsub(' ', '_').downcase
  end

end
