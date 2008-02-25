module Admin::BaseHelper
  def breadcrumb_nav category
    ancestor(category) + link_to(category.name, :id => category)
  end
  
  private
    def ancestor(category, hide_last = false)
      if category.parent
        ancestor(category.parent) + link_to(category.parent.name, :id => category.parent) + (hide_last ? '' : ' > ')
      else
        ""
      end
    end      
end
