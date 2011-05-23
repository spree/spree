class Admin::AdjustmentsController < Admin::ResourceController
  belongs_to :order, :find_by => :number
  destroy.after :reload_order

  private
  
  def reload_order
    @order.reload
  end
end
