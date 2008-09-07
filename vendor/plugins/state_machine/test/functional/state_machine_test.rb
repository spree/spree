require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class VehicleTest < Test::Unit::TestCase
  def setup
    @vehicle = new_vehicle
  end
  
  def test_should_not_allow_access_to_subclass_events
    assert !@vehicle.respond_to?(:reverse)
  end
end

class VehicleUnsavedTest < Test::Unit::TestCase
  def setup
    @vehicle = new_vehicle
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_be_able_to_park
    assert !@vehicle.can_park?
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_be_able_to_ignite
    assert @vehicle.can_ignite?
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_be_saved_after_successful_event
    @vehicle.ignite
    assert !@vehicle.new_record?
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleParkedTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_have_the_seatbelt_on
    assert !@vehicle.seatbelt_on
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
  
  def test_should_raise_exception_if_repair_not_allowed!
    assert_raise(PluginAWeek::StateMachine::InvalidTransition) {@vehicle.repair!}
  end
end

class VehicleIdlingTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
  end
  
  def test_should_be_in_idling_state
    assert_equal 'idling', @vehicle.state
  end
  
  def test_should_have_seatbelt_on
    assert @vehicle.seatbelt_on
  end
  
  def test_should_allow_park
    assert @vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleFirstGearTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
    @vehicle.shift_up
  end
  
  def test_should_be_in_first_gear_state
    assert_equal 'first_gear', @vehicle.state
  end
  
  def test_should_allow_park
    assert @vehicle.park
  end
  
  def test_should_allow_idle
    assert @vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleSecondGearTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
    2.times {@vehicle.shift_up}
  end
  
  def test_should_be_in_second_gear_state
    assert_equal 'second_gear', @vehicle.state
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_allow_shift_up
    assert @vehicle.shift_up
  end
  
  def test_should_allow_shift_down
    assert @vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleThirdGearTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
    3.times {@vehicle.shift_up}
  end
  
  def test_should_be_in_third_gear_state
    assert_equal 'third_gear', @vehicle.state
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_allow_shift_down
    assert @vehicle.shift_down
  end
  
  def test_should_allow_crash
    assert @vehicle.crash
  end
  
  def test_should_not_allow_repair
    assert !@vehicle.repair
  end
end

class VehicleStalledTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
    @vehicle.shift_up
    @vehicle.crash
  end
  
  def test_should_be_in_stalled_state
    assert_equal 'stalled', @vehicle.state
  end
  
  def test_should_be_towed
    assert @vehicle.auto_shop.busy?
    assert_equal 1, @vehicle.auto_shop.num_customers
  end
  
  def test_should_have_an_increased_insurance_premium
    assert_equal 150, @vehicle.insurance_premium
  end
  
  def test_should_not_allow_park
    assert !@vehicle.park
  end
  
  def test_should_allow_ignite
    assert @vehicle.ignite
  end
  
  def test_should_not_change_state_when_ignited
    assert_equal 'stalled', @vehicle.state
  end
  
  def test_should_not_allow_idle
    assert !@vehicle.idle
  end
  
  def test_should_now_allow_shift_up
    assert !@vehicle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@vehicle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@vehicle.crash
  end
  
  def test_should_allow_repair_if_auto_shop_is_busy
    assert @vehicle.repair
  end
  
  def test_should_not_allow_repair_if_auto_shop_is_available
    @vehicle.auto_shop.fix_vehicle
    assert !@vehicle.repair
  end
end

class VehicleRepairedTest < Test::Unit::TestCase
  def setup
    @vehicle = create_vehicle
    @vehicle.ignite
    @vehicle.shift_up
    @vehicle.crash
    @vehicle.repair
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @vehicle.state
  end
  
  def test_should_not_have_a_busy_auto_shop
    assert @vehicle.auto_shop.available?
  end
end

class MotorcycleTest < Test::Unit::TestCase
  def setup
    @motorcycle = create_motorcycle
  end
  
  def test_should_be_in_idling_state
    assert_equal 'idling', @motorcycle.state
  end
  
  def test_should_allow_park
    assert @motorcycle.park
  end
  
  def test_should_not_allow_ignite
    assert !@motorcycle.ignite
  end
  
  def test_should_allow_shift_up
    assert @motorcycle.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@motorcycle.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@motorcycle.crash
  end
  
  def test_should_not_allow_repair
    assert !@motorcycle.repair
  end
end

class CarTest < Test::Unit::TestCase
  def setup
    @car = create_car
  end
  
  def test_should_be_in_parked_state
    assert_equal 'parked', @car.state
  end
  
  def test_should_not_have_the_seatbelt_on
    assert !@car.seatbelt_on
  end
  
  def test_should_not_allow_park
    assert !@car.park
  end
  
  def test_should_allow_ignite
    assert @car.ignite
    assert_equal 'idling', @car.state
  end
  
  def test_should_not_allow_idle
    assert !@car.idle
  end
  
  def test_should_not_allow_shift_up
    assert !@car.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@car.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@car.crash
  end
  
  def test_should_not_allow_repair
    assert !@car.repair
  end
  
  def test_should_allow_reverse
    assert @car.reverse
  end
end

class CarBackingUpTest < Test::Unit::TestCase
  def setup
    @car = create_car
    @car.reverse
  end
  
  def test_should_be_in_backing_up_state
    assert_equal 'backing_up', @car.state
  end
  
  def test_should_allow_park
    assert @car.park
  end
  
  def test_should_not_allow_ignite
    assert !@car.ignite
  end
  
  def test_should_allow_idle
    assert @car.idle
  end
  
  def test_should_allow_shift_up
    assert @car.shift_up
  end
  
  def test_should_not_allow_shift_down
    assert !@car.shift_down
  end
  
  def test_should_not_allow_crash
    assert !@car.crash
  end
  
  def test_should_not_allow_repair
    assert !@car.repair
  end
  
  def test_should_not_allow_reverse
    assert !@car.reverse
  end
end

class AutoShopAvailableTest < Test::Unit::TestCase
  def setup
    @auto_shop = create_auto_shop
  end
  
  def test_should_be_in_available_state
    assert_equal 'available', @auto_shop.state
  end
  
  def test_should_allow_tow_vehicle
    assert @auto_shop.tow_vehicle
  end
  
  def test_should_not_allow_fix_vehicle
    assert !@auto_shop.fix_vehicle
  end
end

class AutoShopBusyTest < Test::Unit::TestCase
  def setup
    @auto_shop = create_auto_shop
    @auto_shop.tow_vehicle
  end
  
  def test_should_be_in_busy_state
    assert_equal 'busy', @auto_shop.state
  end
  
  def test_should_have_incremented_number_of_customers
    assert_equal 1, @auto_shop.num_customers
  end
  
  def test_should_not_allow_tow_vehicle
    assert !@auto_shop.tow_vehicle
  end
  
  def test_should_allow_fix_vehicle
    assert @auto_shop.fix_vehicle
  end
end
