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

        link = link_to(titleized_label, destination_url)

        css_classes = []

        selected = if options[:match_path]
          # TODO: `request.fullpath` for engines mounted at '/' returns '//'
          # which seems an issue with Rails routing.- revisit issue #910
          request.fullpath.gsub('//', '/').starts_with?("#{root_path}admin#{options[:match_path]}")
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

      def link_to_clone(resource, options={})
        link_to_with_icon('exclamation', t(:clone), clone_admin_product_url(resource), options)
      end

      def link_to_delete(resource, options = {}, html_options={})
        options.assert_valid_keys(:url, :caption, :title, :dataType, :success, :error, :name)

        options.reverse_merge! :url => object_url(resource) unless options.key? :url
        options.reverse_merge! :caption => t(:are_you_sure)
        options.reverse_merge! :title => t(:confirm_delete)
        options.reverse_merge! :dataType => 'script'
        options.reverse_merge! :success => "function(r){ $('##{dom_id resource}').fadeOut('hide'); }"
        options.reverse_merge! :error => "function(jqXHR, textStatus, errorThrown){ show_flash_error(jqXHR.responseText); }"
        options.reverse_merge! :name => icon('delete') + ' ' + t(:delete)

        link_to_function_delete(options, html_options)
        #link_to_function_delete_native(options, html_options)
      end

      # this function does not use jConfirm
      def link_to_function_delete_native(options, html_options)
        fn = %Q{
          var answer = confirm("#{t(:are_you_sure)}");
          if (!!answer) { #{link_to_function_delete_ajax(options)} };
        }
        link_to_function options[:name], fn, html_options
      end

      def link_to_function_delete(options, html_options)
        link_to_function options[:name], "jConfirm('#{options[:caption]}', '#{options[:title]}', function(r) {
          if(r){ #{link_to_function_delete_ajax(options)} }
        });", html_options
      end

      def link_to_function_delete_ajax(options)
        %Q{
          $.ajax({
            type: 'POST',
            url: '#{options[:url]}',
            data: ({_method: 'delete', authenticity_token: AUTH_TOKEN}),
            dataType:'#{options[:dataType]}',
            success: #{options[:success]},
            error: #{options[:error]}
          });
        }
      end

      def link_to_with_icon(icon_name, text, url, options = {})
        options[:class] = (options[:class].to_s + ' icon_link').strip
        link_to(icon(icon_name) + ' ' + text, url, options)
      end

      def icon(icon_name)
        icon_name ? image_tag("admin/icons/#{icon_name}.png") : ''
      end

      def button(text, icon_name = nil, button_type = 'submit', options={})
        content_tag('button', content_tag('span', icon(icon_name) + ' ' + text), options.merge(:type => button_type))
      end

      def button_link_to(text, url, html_options = {})
        if (html_options[:method] &&
            html_options[:method].to_s.downcase != 'get' &&
            !html_options[:remote])
          form_tag(url, :method => html_options[:method]) do
            button(text, html_options[:icon])
          end
        else
          if html_options['data-update'].nil? && html_options[:remote]
            object_name, action = url.split('/')[-2..-1]
            html_options['data-update'] = [action, object_name.singularize].join('_')
          end
          html_options.delete('data-update') unless html_options['data-update']
          link_to(text_for_button_link(text, html_options), url, html_options_for_button_link(html_options))
        end
      end

      def button_link_to_function(text, function, html_options = {})
        link_to_function(text_for_button_link(text, html_options), function, html_options_for_button_link(html_options))
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
        options = { :class => 'button' }.update(html_options)
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
