
# The Tagging join model. This model is automatically generated and added to your app if you run the tagging generator included with has_many_polymorphs.

class Tagging < ActiveRecord::Base 
 
  belongs_to :<%= parent_association_name -%><%= ", :foreign_key => \"#{parent_association_name}_id\", :class_name => \"Tag\"" if options[:self_referential] %>
  belongs_to :taggable, :polymorphic => true
  
  # If you also need to use <tt>acts_as_list</tt>, you will have to manage the tagging positions manually by creating decorated join records when you associate Tags with taggables.
  # acts_as_list :scope => :taggable
    
  # This callback makes sure that an orphaned <tt>Tag</tt> is deleted if it no longer tags anything.
  def after_destroy
    <%= parent_association_name -%>.destroy_without_callbacks if <%= parent_association_name -%> and <%= parent_association_name -%>.taggings.count == 0
  end    
end
