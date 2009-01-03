class Canine < ActiveRecord::Base
  self.abstract_class = true
  
  def an_abstract_method
    :correct_abstract_method_response
  end
  
end

