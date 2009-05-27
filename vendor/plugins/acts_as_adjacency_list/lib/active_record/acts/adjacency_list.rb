# ActsAsAdjacencyList
# This code is a modified acts_as_tree
module ActiveRecord
  module Acts #:nodoc:
    module AdjacencyList #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Specify this act if you want to model a tree structure by providing a parent association and a children
      # association. This act requires that you have a foreign key column, which by default is called parent_id.
      #
      #   class Category < ActiveRecord::Base
      #     acts_as_tree :order => "name"
      #   end
      #
      #   Example:
      #   root
      #    \_ child1
      #         \_ subchild1
      #         \_ subchild2
      #
      #   root      = Category.create("name" => "root")
      #   child1    = root.children.create("name" => "child1")
      #   subchild1 = child1.children.create("name" => "subchild1")
      #
      #   root.parent   # => nil
      #   child1.parent # => root
      #   root.children # => [child1]
      #   root.children.first.children.first # => subchild1
      #
      # In addition to the parent and children associations, the following instance methods are added to the class
      # after specifying the act:
      # * siblings          : Returns all the children of the parent, excluding the current node ([ subchild2 ] when called from subchild1)
      # * self_and_siblings : Returns all the children of the parent, including the current node ([ subchild1, subchild2 ] when called from subchild1)
      # * ancestors         : Returns all the ancestors of the current node ([child1, root] when called from subchild2)
      # * root              : Returns the root of the current node (root when called from subchild2)
      module ClassMethods
        # Configuration options are:
        #
        # * <tt>foreign_key</tt> - specifies the column name to use for tracking of the tree (default: parent_id)
        # * <tt>order</tt> - makes it possible to sort the children according to this SQL snippet.
        # * <tt>counter_cache</tt> - keeps a count in a children_count column if set to true (default: false).
        def acts_as_adjacency_list(options = {})
          configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil }
          configuration.update(options) if options.is_a?(Hash)

          belongs_to :parent, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]
          has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => :destroy

          after_destroy { |node| node.reorder_and_save(node.siblings) }
          before_create { |node| node.position ||= node.parent.children.length }
          after_create  { |node| node.reorder_and_save(node.self_and_siblings) }

          class_eval <<-EOV
            include ActiveRecord::Acts::AdjacencyList::InstanceMethods

	    def self.ordered
	          #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}}
            end

	    def self.ordered?
	          #{configuration[:order].nil? ? false : true}
            end

            def self.roots
              find(:all, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end

            def self.root
              find(:first, :conditions => "#{configuration[:foreign_key]} IS NULL", :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end
          EOV
        end
      end

      module InstanceMethods
        # Returns list of ancestors, starting from parent until root.
        #
        #   subchild1.ancestors # => [child1, root]
        def ancestors
          node, nodes = self, []
          nodes << node = node.parent while node.parent
          nodes
        end

        def descendents
          return [] unless children
          result = []
          children.each do |child|
            result << child
            result.concat(child.descendents)
          end
          result
        end

        def root
          node = self
          node = node.parent while node.parent
          node
        end

        def siblings
          self_and_siblings - [self]
        end

        def self_and_siblings
          parent ? parent.children : self.class.roots
        end

        def root?
          parent.nil?
        end

        def leaf?
          children.empty?
        end

        def leaves
          return [self] if leaf?

          nodes = []
          children.each do |child|
            nodes.concat(child.leaves)
          end

          nodes
        end
     
        def remove
          raise "Deprecated.  Use prune"
          children.each { |c| c.remove }
          self.class.delete(self.id)
          self.parent_id = nil
          # wander away little fella
          return
        end

        def prune
          self.reload
          self.destroy
          reorder_and_save(siblings)
        end

        def prune_back
          self.reload
          self.destroy
          if siblings.empty?
            parent.prune_back unless parent.nil?
          else
            reorder_and_save(siblings)
          end
        end

        ## this function is for inserting a new node into the tree
        def insert_at(parent = nil, position = -1)
          self.parent_id = parent.nil? ? nil : parent.id
          position = parent.children.length if parent && position == -1
          self.position = position
          self.save
          self.reload

          reorder_and_save(siblings.insert(self.position, self))
          self
        end

        ## this function is for moving node from one part of the tree to another
        def move_to(parent = nil, position = -1)
          orig_parent = self.parent
          insert_at(parent, position)
          reorder_and_save(orig_parent.children) unless 
            orig_parent.nil? || orig_parent == parent
          self
        end

        def decrement_position(count = 1)
          self.position -= count;
          self.position = 0 if self.position < 0;
          reorder_and_save(siblings.insert(self.position, self))
          self
        end

        def increment_position(count = 1)
          self.position += count;
          reorder_and_save(siblings.insert(self.position, self))
          self
        end

        def merge(node)
          if merge_match?(node)
#            logger.info("adjacency_list.merge - match at #{node.id}")
            node.children.each do |branch_child|
              merged = false
              children.each do |base_child|
                if base_child.merge_match?(branch_child)
                  base_child.merge(branch_child)
                  merged = true
                  break
                end
              end
#              logger.info("adjacency_list.merge - mergining child #{branch_child.id}")
              branch_child.insert_at(self) unless merged
            end
#            logger.info("destroy node #{node.id}")
            node.prune
          else
            logger.info("adjacency_list.merge - merge at #{parent.id}")
            node.insert_at(parent)
          end
        end

        def merge_match?(node)
          raise "Please implement merge_match? in your class"
        end    

        def reorder_and_save(nodes)
#          puts "reorder_and_save start"
          nodes.compact!
          nodes.each_with_index do |node, i|
            node.position = i
            node.save!
#            puts "reorder_and_save id: #{node.id}, position: #{node.position}"
          end
        end

      end
    end
  end
end

