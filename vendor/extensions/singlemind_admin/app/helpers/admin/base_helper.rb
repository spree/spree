require_dependency "#{RAILS_ROOT}/app/helpers/admin/base_helper.rb"

module Admin::BaseHelper

  def link_to_edit(resource)
    link_to image_tag('/images/admin/icons/edit.gif') + ' ' + t("edit"), edit_object_url(resource)
  end
  
  def link_to_delete(resource)
    link_to image_tag('/images/admin/icons/delete.gif') + ' ' + t("delete"), object_url(resource), :confirm => t('are_you_sure'), :method => :delete 
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
    if args.include?(controller.controller_name.to_sym)
      css_class = 'active'
    end
    content_tag('li', link, :class => css_class)
  end
  
end
