
require 'canine'

class Dog < Canine
  attr_accessor :after_find_test, :after_initialize_test
  set_table_name "bow_wows"
  
  def after_find
    @after_find_test = true
#    puts "After find called on #{name}."
  end
  
  def after_initialize
    @after_initialize_test = true
  end
  
end

