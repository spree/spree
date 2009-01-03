class ApplicationController < ActionController::Base
  before_filter :i_should_only_be_run_once, 
                :only => 'action_with_inherited_before_filter'
  
  def i_should_only_be_run_once
    true
  end
  private :i_should_only_be_run_once
end