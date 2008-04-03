class Admin::InventoryUnitsController < Admin::BaseController
  require_role "admin"
  
  def adjust
    @variant = Variant.find(params[:id])
    if request.post?
      @level = InventoryLevel.new(params[:level])
      @level.on_hand = @variant.inventory(InventoryUnit::Status::ON_HAND)
      begin
        #throw "Invalid Adjustment Quantity" unless @level.valid?
        InventoryUnit.create_on_hand(@variant, @level.adjustment) if @level.adjustment > 0
        InventoryUnit.destroy_on_hand(@variant, @level.adjustment) if @level.adjustment < 0
        flash.now[:notice] = "Inventory level has been adjusted."
        @variant.reload
        @level = InventoryLevel.new(:adjustment => 0)
      rescue 
        flash.now[:error] = "Error occurred while updating inventory."
        flash.now[:error] = "Invalid adjustment quantity" unless @level.errors.empty?
      end
    else
      @level = InventoryLevel.new(:adjustment => 0)
    end
  end
  
end

