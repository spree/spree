module Spree::Checkout
  class ActionOptions < ResourceController::ActionOptions
    
    block_accessor :edit_hook, :update_hook
    
    def dup
      returning self.class.new do |duplicate|
        duplicate.instance_variable_set(:@collector, wants.dup)
        duplicate.instance_variable_set(:@before, before.dup)             unless before.nil?
        duplicate.instance_variable_set(:@after, after.dup)               unless after.nil?
        duplicate.instance_variable_set(:@edit_hook, edit_hook.dup)       unless edit_hook.nil?
        duplicate.instance_variable_set(:@update_hook, update_hook.dup)   unless update_hook.nil?
        duplicate.instance_variable_set(:@flash, flash.dup)               unless flash.nil?
        duplicate.instance_variable_set(:@flash_now, flash_now.dup)       unless flash_now.nil?
      end
    end
  end
end