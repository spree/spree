module Admin::BaseHelper
  def link_to_new(resource)
    link_to_with_icon('add', t("new"), edit_object_url(resource))
  end

  def link_to_edit(resource)
    link_to_with_icon('edit', t("edit"), edit_object_url(resource))
  end
  
  def link_to_delete(resource, options = {})
	  options.assert_valid_keys(:url, :caption, :title)

		options.reverse_merge! :url => object_url(resource) unless options.key? :url
    options.reverse_merge! :caption => t('are_you_sure')
    options.reverse_merge! :title => t('confirm_delete')

    #link_to_with_icon('delete', t("delete"), object_url(resource), :confirm => t('are_you_sure'), :method => :delete )
		link_to_function icon("delete") + ' ' + t("delete"), "jConfirm('#{options[:caption]}', '#{options[:title]}', function(r) { 
      if(r){ 
        jQuery.ajax({
          type: 'POST',
          url: '#{options[:url]}',
          data: ({_method: 'delete', authenticity_token: AUTH_TOKEN}),
          success: function(r){ jQuery('##{dom_id resource}').fadeOut('hide'); } 
        });
      }
		});"
  end
  
  def link_to_with_icon(icon_name, text, url, options = {})
    link_to(icon(icon_name) + ' ' + text, url, options.update(:class => 'iconlink'))
  end

  def icon(icon_name)
    image_tag("/images/admin/icons/#{icon_name}.png")
  end
  
  def button(text, icon = nil, button_type = 'submit')
    content_tag('button', content_tag('span', text), :type => button_type)
  end

  def button_link_to(text, url, html_options = {})
    link_to(text_for_button_link(text, html_options), url, html_options_for_button_link(html_options))
  end
  
  def button_link_to_function(text, function, html_options = {})
    link_to_function(text_for_button_link(text, html_options), function, html_options_for_button_link(html_options))
  end
  
  def button_link_to_remote(text, options, html_options = {})
    link_to_remote(text_for_button_link(text, html_options), options, html_options_for_button_link(html_options))
  end
  
  def text_for_button_link(text, html_options)
    s = ''
    if html_options[:icon]
      s << icon(html_options.delete(:icon)) + ' &nbsp; '
    end
    s << text
    content_tag('span', s)
  end

  def html_options_for_button_link(html_options)
    options = {:class => 'button'}.update(html_options)
  end



  # Make an admin tab that coveres one or more resources supplied by symbols
  # Option hash may follow. Valid options are
  #   * :label to override link text, otherwise based on the first resource name (translated)
  #   * :route to override automatically determining the default route
  #   * :match_path as an alternative way to control when the tab is active, /products would match /admin/products, /admin/products/5/variants etc.
  def tab(*args)
    options = {:label => args.first.to_s}
    if args.last.is_a?(Hash)
      options = options.merge(args.pop)
    end
    options[:route] ||=  "admin_#{args.first}"

    destination_url = send("#{options[:route]}_path")

    return("") unless url_options_authenticate?(ActionController::Routing::Routes.recognize_path(destination_url))

    ## if more than one form, it'll capitalize all words
    label_with_first_letters_capitalized = t(options[:label]).gsub(/\b\w/){$&.upcase}
    link = link_to(label_with_first_letters_capitalized, destination_url)
    
    css_classes = []

    selected = if options[:match_path]
      request.request_uri.starts_with?("/admin#{options[:match_path]}")
    else
      args.include?(controller.controller_name.to_sym)
    end
    css_classes << 'selected' if selected

    if options[:css_class]
      css_classes << options[:css_class]
    end
    content_tag('li', link, :class => css_classes.join(' '))
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

  def get_additional_field_value(controller, field)  
    attribute = field[:name].gsub(" ", "_").downcase

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
  #   <% form_for @project do |project_form| -%>
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
    out << fields.hidden_field(:_delete) unless fields.object.new_record?
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
      definition = object.class.preference_definitions[key]
      type = definition.instance_eval{@type}.to_sym
      
      form.label("preferred_#{key}", t(key)+": ") +
        preference_field(form, "preferred_#{key}", :type => type)
    }.join("<br />")
  end

end
