class RedirectSpecController < ApplicationController

  def action_with_no_redirect
    render :text => "this is just here to keep this from causing a MissingTemplate error"
  end
  
  def action_with_redirect_to_somewhere
    redirect_to :action => 'somewhere'
  end
  
  def action_with_redirect_to_other_somewhere
    redirect_to :controller => 'render_spec', :action => 'text_action'
  end
  
  def action_with_redirect_to_somewhere_and_return
    redirect_to :action => 'somewhere' and return
    render :text => "this is after the return"
  end
  
  def somewhere
    render :text => "this is just here to keep this from causing a MissingTemplate error"
  end
  
  def action_with_redirect_to_rspec_site
    redirect_to "http://rspec.rubyforge.org"
  end
  
  def action_with_redirect_back
    redirect_to :back
  end
  
  def action_with_redirect_in_respond_to
    respond_to do |wants|
      wants.html { redirect_to :action => 'somewhere' }
    end
  end

  def action_with_redirect_which_creates_query_string
    redirect_to :action => "somewhere", :id => 1111, :param1 => "value1", :param2 => "value2"
  end

  # note: sometimes this is the URL which rails will generate from the hash in
  # action_with_redirect_which_creates_query_string
  def action_with_redirect_with_query_string_order1
    redirect_to "http://test.host/redirect_spec/somewhere/1111?param1=value1&param2=value2"
  end

  # note: sometimes this is the URL which rails will generate from the hash in
  # action_with_redirect_which_creates_query_string
  def action_with_redirect_with_query_string_order2
    redirect_to "http://test.host/redirect_spec/somewhere/1111?param2=value2&param1=value1"
  end

  def action_with_redirect_to_unroutable_url_inside_app
    redirect_to :controller => "nonexistant", :action => "none"
  end

end

