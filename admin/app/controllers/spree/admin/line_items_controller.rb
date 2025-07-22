module Spree
  module Admin
    class LineItemsController < Spree::Admin::ResourceController
      belongs_to 'spree/order', find_by: :number

      layout 'turbo_rails/frame'

      def create
        @variant = Spree::Variant.accessible_by(current_ability, :manage).find(params[:line_item][:variant_id])

        @order.transaction do
          line_item_result = create_service.call(order: @order, line_item_attributes: permitted_resource_params)

          if line_item_result.success?
            unless @order.completed?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              result = Spree::Dependencies.checkout_advance_service.constantize.call(order: @order, state: max_state)

              unless result.success?
                flash[:error] = result.error.value.full_messages.to_sentence
                raise ActiveRecord::Rollback
              end
            end

            flash[:success] = Spree.t(:successfully_created, resource: Spree.t(:line_item))
          else
            flash[:error] = line_item_result.value.errors.full_messages.to_sentence
            raise ActiveRecord::Rollback
          end
        end

        redirect_to spree.edit_admin_order_path(@order, line_item_updated: true)
      rescue ActiveRecord::Rollback
        redirect_to spree.edit_admin_order_path(@order)
      end

      def update
        @order.transaction do
          line_item_result = update_service.call(line_item: @line_item, line_item_attributes: permitted_resource_params)

          if line_item_result.success?
            unless @order.completed?
              max_state = if @order.ship_address.present?
                            @order.ensure_updated_shipments
                            'payment'
                          else
                            'address'
                          end

              result = Spree::Dependencies.checkout_advance_service.constantize.call(order: @order, state: max_state)

              unless result.success?
                flash[:error] = result.error.value.full_messages.to_sentence
                raise ActiveRecord::Rollback
              end
            end

            flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:line_item))
          else
            flash[:error] = line_item_result.value.errors.full_messages.to_sentence
            raise ActiveRecord::Rollback
          end
        end

        redirect_to spree.edit_admin_order_path(@order, line_item_updated: true)
      rescue ActiveRecord::Rollback
        redirect_to spree.edit_admin_order_path(@order)
      end

      def destroy
        result = destroy_service.call(line_item: @line_item)
        flash[:success] = Spree.t(:successfully_removed, resource: Spree.t(:line_item)) if result.success?

        redirect_to spree.edit_admin_order_path(@order, line_item_updated: true)
      end

      def reset_digital_links_limit
        @line_item.digital_links.update_all(access_counter: 0, created_at: Time.current, updated_at: Time.current)
        flash[:success] = Spree.t('admin.successfully_reset_digital_links_limit')

        redirect_to spree.edit_admin_order_path(@order)
      end

      private

      def model_class
        Spree::LineItem
      end

      def collection_url
        spree.edit_admin_order_path(@order)
      end

      def update_service
        Spree::Dependencies.line_item_update_service.constantize
      end

      def destroy_service
        Spree::Dependencies.line_item_destroy_service.constantize
      end

      def create_service
        Spree::Dependencies.line_item_create_service.constantize
      end

      def build_resource
        if parent_data.present?
          model_class.new(resource.model_name => parent)
        else
          model_class.new
        end
      end

      def permitted_resource_params
        params.require(:line_item).permit(permitted_line_item_attributes)
      end
    end
  end
end
