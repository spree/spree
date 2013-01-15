Spree::ContentController.class_eval do
  after_filter :fire_visited_path, :only => :show
  after_filter :fire_visited_action, :except => :show

  def fire_visited_path
    fire_event('spree.content.visited', :path => "content/#{params[:path]}")
  end

  def fire_visited_action
    fire_event('spree.content.visited', :path => "content/#{params[:action]}")
  end

end
