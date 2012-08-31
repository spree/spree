module Spree
  module Admin
    module NavigationHelper
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

        destination_url = options[:url] || spree.send("#{options[:route]}_path")

        titleized_label = t(options[:label], :default => options[:label]).titleize

        css_classes = []

        if options[:icon]
          link = link_to_with_icon(options[:icon], titleized_label, destination_url)
          css_classes << 'tab-with-icon'
        else
          link = link_to(titleized_label, destination_url)
        end

        selected = if options[:match_path]
          request.fullpath.starts_with?("#{root_path}admin#{options[:match_path]}")
        else
          args.include?(controller.controller_name.to_sym)
        end
        css_classes << 'selected' if selected

        if options[:css_class]
          css_classes << options[:css_class]
        end
        content_tag('li', link, :class => css_classes.join(' '))
      end

      def link_to_clone(resource, options={})
        link_to_with_icon('exclamation', t(:clone), clone_admin_product_url(resource), options)
      end

      def link_to_new(resource)
        link_to_with_icon('add', t(:new), edit_object_url(resource))
      end

      def link_to_edit(resource, options={})
        link_to_with_icon('edit', t(:edit), edit_object_url(resource), options)
      end

      def link_to_edit_url(url, options={})
        link_to_with_icon('edit', t(:edit), url, options)
      end

      def link_to_delete(resource, options={})
        url = options[:url] || object_url(resource)
        name = options[:name] || icon('delete') + ' ' + t(:delete)
        link_to name, url,
          :class => "delete-resource",
          :data => { :confirm => t(:are_you_sure) }
      end

      def link_to_with_icon(icon_name, text, url, options = {})
        options[:class] = (options[:class].to_s + " icon_link #{icon_name}").strip
        link_to(text, url, options)
      end

      def icon(icon_name)
        icon_name ? content_tag(:i, '', :class => icon_name) : ''
      end

      def button(text, icon_name = nil, button_type = 'submit', options={})
        button_tag(text, options.merge(:type => button_type, :class => "#{icon_name} button"))
      end

      def button_link_to(text, url, html_options = {})
        if (html_options[:method] &&
            html_options[:method].to_s.downcase != 'get' &&
            !html_options[:remote])
          form_tag(url, :method => html_options.delete(:method)) do
            button(text, html_options.delete(:icon), nil, html_options)
          end
        else
          if html_options['data-update'].nil? && html_options[:remote]
            object_name, action = url.split('/')[-2..-1]
            html_options['data-update'] = [action, object_name.singularize].join('_')
          end
          
          html_options.delete('data-update') unless html_options['data-update']
          
          html_options[:class] = 'button'

          if html_options[:icon]
            html_options[:class] += " #{html_options[:icon]}"
          end
          link_to(text_for_button_link(text, html_options), url, html_options)
        end
      end

      def text_for_button_link(text, html_options)
        s = ''
        s << text
        raw(s)
      end

      def configurations_menu_item(link_text, url, description = '')
        %(<tr>
          <td>#{link_to(link_text, url)}</td>
          <td>#{description}</td>
        </tr>
        ).html_safe
      end

      def configurations_sidebar_menu_item(link_text, url, options = {})
        options.merge!(:class => url.include?(controller.controller_name) ? 'active' : nil)
        content_tag(:li, options) do
          link_to(link_text, url)
        end
      end
    end
  end
end
