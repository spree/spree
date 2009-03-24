module Admin::BaseHelper

  def link_to_new(resource)
    link_to_with_icon('add', t("new"), edit_object_url(resource))
  end

  def link_to_edit(resource)
    link_to_with_icon('edit', t("edit"), edit_object_url(resource))
  end
  
  def link_to_delete(resource)
    link_to_with_icon('delete', t("delete"), object_url(resource), :confirm => t('are_you_sure'), :method => :delete )
  end
  
  def link_to_with_icon(icon_name, text, url, options = {})
    link_to(icon(icon_name) + ' ' + text, url, options.update(:class => 'iconlink'))
  end

  def icon(icon_name)
    image_tag("/images/admin/icons/#{icon_name}.png")
  end
  
  def button(text, icon = nil)
    content_tag('button', content_tag('span', text))
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
    link = link_to(t(options[:label]).capitalize, send("#{options[:route]}_path"))
    
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
  
end
