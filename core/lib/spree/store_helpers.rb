# Methods added to this helper will be available to all templates in the application.
module StoreHelpers

  # helper to determine if its appropriate to show the store menu
  def store_menu?
    return true unless %w{thank_you}.include? @current_action
    false
  end

end