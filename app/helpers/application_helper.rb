# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  # helper to determine if its appropriate to show the store menu
  def store_menu?
    return true unless %w{thank_you}.include? @current_action
    false
  end

  # Renders all the extension partials that may have been specified in the extensions
  def render_extra_partials(f)
    @extension_partials.inject("") do |extras, partial|
      extras += render :partial => partial, :locals => {:f => f}
    end
  end
  
  def flag_image(code)
    "#{code.to_s.split("-").last.downcase}.png"
  end                      
end