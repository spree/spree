class RenderSpecController < ApplicationController
  set_view_path File.join(File.dirname(__FILE__), "..", "views")
  
  def some_action
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def action_which_renders_template_from_other_controller
    render :template => 'controller_spec/action_with_template'
  end
  
  def text_action
    render :text => "this is the text for this action"
  end
  
  def action_with_partial
    render :partial => "a_partial"
  end
  
  def action_that_renders_nothing
    render :nothing => true
  end
  
  def action_with_alternate_layout
    render :layout => 'simple'
  end
end
