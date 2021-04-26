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

            if @moved_item && @new_parent
              @moved_item.move_to_child_with_index(@new_parent, params[:new_position_idx].to_i)
            else
              head :bad_request
            end

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
