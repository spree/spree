module Spree
  module Api
    module V2
      module Platform
        class MenuItemsController < ResourceController
          def reposition
            @moved_item = scope.find(params[:moved_item_id])
            @new_parent = if params[:new_parent_id].nil?
                            nil
                          else
                            scope.find(params[:new_parent_id])
                          end

            @moved_item.move_with_index(params[:new_position_idx].to_i, @new_parent)

            if @moved_item.save
              head :no_content
            end
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
