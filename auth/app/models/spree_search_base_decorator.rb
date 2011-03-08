Spree::Search::Base.class_eval do
  def add_authorization_scope(base_scope)
    if @controller
      base_scope.accessible_by @controller.current_ability, :index
    else
      base_scope
    end
  end
end
