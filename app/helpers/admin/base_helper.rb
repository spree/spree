require_dependency "#{RAILS_ROOT}/app/helpers/admin/base_helper.rb"

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

  # Make an admin tab that coveres one or more resources supplied by symbols
  # Option hash may follow. Valid options are
  #   * :label to override link text, otherwise based on the first resource name (translated)
  #   * :route to override automatically determining the default route
  def tab(*args)
    options = {:label => args.first.to_s}
    if args.last.is_a?(Hash)
      options = options.merge args.pop
    end
    options[:route] ||=  "admin_#{args.first}"
    link = link_to(t(options[:label]).capitalize, send("#{options[:route]}_path"))
    
    css_classes = []
    if args.include?(controller.controller_name.to_sym)
      css_classes << 'selected'
    end
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
    concat(html, proc.binding)
  end

  def class_for_error(model, method)
    if error_message_on :product, :name
    end
  end

  
end
