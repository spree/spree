class ChangeTaxonsToNestedSet < ActiveRecord::Migration
  def up
    add_column :taxons, :lft, :integer
    add_column :taxons, :rgt, :integer

    Spree::Taxon.reset_column_information # So the new root ids get saved

    # Temporarily set the table back to taxons
    Spree::Taxon.table_name = 'taxons'

    Spree::Taxon.class_eval do
      # adapted from awesome nested set to use 'position' information
      indices = {}

      left_column_name = 'lft'
      right_column_name = 'rgt'
      quoted_parent_column_name = 'parent_id'
      scope = lambda{|node|}

      set_left_and_rights = lambda do |node|
        # set left
        node[left_column_name] = indices[scope.call(node)] += 1
        # find
        where("#{quoted_parent_column_name} = ?", node).order('position ASC').each{ |n| set_left_and_rights.call(n) }
        # set right
        node[right_column_name] = indices[scope.call(node)] += 1
        node.save!
      end

      # Find root node(s)
      where("#{quoted_parent_column_name}" => nil).order('position ASC').each do |root_node|
        # setup index for this scope
        indices[scope.call(root_node)] ||= 0
        set_left_and_rights.call(root_node)
      end
    end

    # Set it back after the migration
    Spree::Taxon.table_name = 'spree_taxons'
  end

  def down
    remove_column :taxons, :lft
    remove_column :taxons, :rgt
  end
end
