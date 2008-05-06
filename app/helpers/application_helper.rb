# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  # helper to determine if its appropriate to show the store menu
  def store_menu?
    return true unless %w{thank_you}.include? @current_action
    false
  end

  def stylesheets
    stylesheets = [stylesheet_link_tag("spree"), stylesheet_link_tag("application")]
    ["#{controller.controller_name}/_controller", "#{controller.controller_name}/#{:action_name}"].each do |stylesheet|
      if File.exists? "#{RAILS_ROOT}/public/stylesheets/#{stylesheet}.css" 
        stylesheets << stylesheet_link_tag(stylesheet)   
      # TODO - consider bringing this back to use with stylesheets in the extension
      #else
      #  stylesheets << stylesheet_link_tag(stylesheet, :plugin=>"spree") if File.exists? "#{RAILS_ROOT}/public/plugin_assets/spree/stylesheets/#{stylesheet}.css"
      end
    end
    stylesheets.compact.join("\n")
  end  
end
