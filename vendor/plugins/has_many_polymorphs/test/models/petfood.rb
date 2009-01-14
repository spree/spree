# see http://dev.rubyonrails.org/ticket/5935
require 'eaters_foodstuff'
require 'petfood'
require 'cat'
module Aquatic; end
require 'aquatic/fish'
require 'dog'
require 'wild_boar'
require 'kitten'
require 'tabby'
require 'extension_module'
require 'other_extension_module'

class Petfood < ActiveRecord::Base
  set_primary_key 'the_petfood_primary_key'
  has_many_polymorphs :eaters, 
    :from => [:dogs, :petfoods, :wild_boars, :kittens, 
                    :tabbies, :"aquatic/fish"], 
#    :dependent => :destroy, :destroy is now the default
    :rename_individual_collections => true,
    :as => :foodstuff,
    :foreign_key => "foodstuff_id",
    :ignore_duplicates => false,
    :conditions => "NULL IS NULL",
    :order => "eaters_foodstuffs.updated_at ASC",
    :parent_order => "petfoods.the_petfood_primary_key DESC",
    :parent_conditions => "petfoods.name IS NULL OR petfoods.name != 'Snausages'",
    :extend => [ExtensionModule, OtherExtensionModule, proc {}],
    :join_extend => proc { 
      def a_method
        :correct_join_result
      end
      },
    :parent_extend => proc {
      def a_method
        :correct_parent_proc_result
      end
    }
 end
