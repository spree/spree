
require 'extension_module'

class BeautifulFightRelationship < ActiveRecord::Base
  set_table_name 'keep_your_enemies_close'

  belongs_to :enemy, :polymorphic => true
  belongs_to :protector, :polymorphic => true
  # polymorphic relationships with column names different from the relationship name
  # are not supported by Rails
  
  acts_as_double_polymorphic_join :enemies => [:dogs, :kittens, :frogs], 
    :protectors =>  [:wild_boars, :kittens, :"aquatic/fish", :dogs],
    :enemies_extend => [ExtensionModule, proc {}],
    :protectors_extend => proc {
      def a_method
        :correct_proc_result
      end
    },
    :join_extend => proc {
      def a_method
        :correct_join_result                                                                                                            
      end
    }
end

