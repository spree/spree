# see http://dev.rubyonrails.org/ticket/5935
module Aquatic; end
require 'aquatic/fish'
require 'aquatic/pupils_whale'

class Aquatic::Whale < ActiveRecord::Base
  # set_table_name "whales"
  
  has_many_polymorphs(:aquatic_pupils, :from => [:dogs, :"aquatic/fish"],
                      :through => "aquatic/pupils_whales") do
                        def a_method
                          :correct_block_result 
                        end
                      end    
end
