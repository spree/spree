module AwesomeNestedSet
  module MovableDecorator
    # Had to monkey patch AwesomeNestedSet, adding the ability to sort root items.

    # AwesomeNestedSet only give you .move_to_child_with_index,
    # this works a treat for sorting any item that is nested inside a parent,
    # but if you have items at the root level, you get nothing out of the box for re-ordering position.

    # Pass the new index of the item and its new parent node.
    # if no node is passed (node = nil), it assumes you are going to / or already are at the root level and passes the
    # process to .move_to_root_with_index, if a node is present it uses .move_to_child_with_index from AwesomeNestedSet
    def move_with_index(index, node = nil)
      if node.nil?
        move_to_root_with_index(index)
      else
        move_to_child_with_index(node, index)
      end
    end

    def move_to_root_with_index(index)
      # If we are already at level 0 the item should be root? => true
      # and we can skip moving the item to root.
      move_to_root unless level == 0 && root?

      # Sort the positioning of the item
      # at root level based on its siblings.
      my_position = siblings.to_a.index(self)
      if my_position && my_position < index
        move_to_right_of(siblings[index])
      elsif my_position && my_position == index
        # do nothing. already there.
      else
        move_to_left_of(siblings[index])
      end
    end
  end
end

CollectiveIdea::Acts::NestedSet::Model::Movable.prepend AwesomeNestedSet::MovableDecorator
