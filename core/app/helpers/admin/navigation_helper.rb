module Admin::NavigationHelper

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

    return("") unless url_options_authenticate?(Rails.application.routes.recognize_path(destination_url))

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


  def link_to_new(resource)
    link_to_with_icon('add', t("new"), edit_object_url(resource))
  end

  def link_to_edit(resource)
    link_to_with_icon('edit', t("edit"), edit_object_url(resource))
  end

  def link_to_clone(resource)
    link_to_with_icon('exclamation', t("clone"), clone_admin_product_url(resource))
  end

  def link_to_delete(resource, options = {})
    options.assert_valid_keys(:url, :caption, :title, :dataType, :success)

    options.reverse_merge! :url => object_url(resource) unless options.key? :url
    options.reverse_merge! :caption => t('are_you_sure')
    options.reverse_merge! :title => t('confirm_delete')
    options.reverse_merge! :dataType => 'script'
    options.reverse_merge! :success => "function(r){ jQuery('##{dom_id resource}').fadeOut('hide'); }"

    #link_to_with_icon('delete', t("delete"), object_url(resource), :confirm => t('are_you_sure'), :method => :delete )
    link_to_function icon("delete") + ' ' + t("delete"), "jConfirm('#{options[:caption]}', '#{options[:title]}', function(r) {
      if(r){
        jQuery.ajax({
          type: 'POST',
          url: '#{options[:url]}',
          data: ({_method: 'delete', authenticity_token: AUTH_TOKEN}),
          dataType:'#{options[:dataType]}',
          success: #{options[:success]}
        });
      }
    });"
  end

  def link_to_with_icon(icon_name, text, url, options = {})
    options[:class] = (options[:class].to_s + " icon_link").strip
    link_to(icon(icon_name) + ' ' + text, url, options)
  end

  def icon(icon_name)
    image_tag("/images/admin/icons/#{icon_name}.png")
  end

  def button(text, icon = nil, button_type = 'submit', options={})
    content_tag('button', content_tag('span', text), options.merge(:type => button_type))
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

  def link_to_remote(name, options = {}, html_options = {})
    options[:before] ||= "jQuery(this).parent().hide(); jQuery('#busy_indicator').show();"
    options[:complete] ||= "jQuery('#busy_indicator').hide()"
    link_to_function(name, remote_function(options), html_options || options.delete(:html))
  end

  def text_for_button_link(text, html_options)
    s = ''
    if html_options[:icon]
      s << icon(html_options.delete(:icon)) + ' '
    end
    s << text
    content_tag('span', raw(s))
  end

  def html_options_for_button_link(html_options)
    options = {:class => 'button'}.update(html_options)
  end

  def configurations_menu_item(link_text, url, description = '')
    %(<tr>
      <td>#{link_to(link_text, url)}</td>
      <td>#{description}</td>
    </tr> 
    )
  end
  
end
