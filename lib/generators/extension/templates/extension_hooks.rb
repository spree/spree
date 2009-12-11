class <%= class_name.gsub(/Extension$/, '') %>Hooks < Spree::ThemeSupport::Hook::ViewListener

  #
  # In this file you can insert content into hooks available in the default templates
  # and avoid overriding a template in many situations. Multiple extensions can write
  # content into the hooks, its added cumulatively in the order the extensions are loaded.
  #
  # Usage
  #
  # Option 1, supply hook name followed by any arguments that are valid for 'render'
  # e.g.
  #   render_on :homepage_above_products, 'shared/welcome' # renders a partial
  # or...
  #   render_on :homepage_above_products, :text => "<h1>Welcome!</h1>"
  #
  #
  # Option 2, call render_on with block which returns the content to be inserted. The block
  # will have access to any helper available to your views.
  #
  # e.g. adding a link below product details:
  #
  #   render_on :product_below_description do
  #    '<p>' + link_to('Back to products', products_path) + '</p>'
  #   end
  #
  # or adding a new tab to the admin navigation
  #
  #   render_on :admin_tabs do
  #     tab(:taxonomies)
  #   end
  #

end
