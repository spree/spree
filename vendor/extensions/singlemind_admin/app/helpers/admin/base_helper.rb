require_dependency "#{RAILS_ROOT}/app/helpers/admin/base_helper.rb"

module Admin::BaseHelper

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
      css_class = 'on'
    end
    content_tag('span', link, :class => css_class)
  end
  
end
