module Spree
  module Api
    module V2
      module Platform
        class MenuItemsController < ResourceController
          def reposition
            puts "MSK: #{params[:new_parent_id]}"
            @moved_item = Spree::MenuItem.find(params[:moved_item_id])
            @new_parent = if params[:new_parent_id].nil?
                            nil
                          else
                            Spree::MenuItem.find(params[:new_parent_id])
                          end

            @moved_item.move_with_index(params[:new_position_idx].to_i, @new_parent)
          end

          private

          def model_class
            Spree::MenuItem
          end
        end
      end
    end
  end
end
