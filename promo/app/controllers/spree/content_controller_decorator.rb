Spree::ContentController.class_eval do
  after_filter :fire_visited_event

  def fire_visited_event
    fire_event('spree.content.visited', :path => path = "content/#{params[:action]}")
  end
end
