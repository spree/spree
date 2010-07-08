require 'test_helper'

class PreferenceTest < ActiveSupport::TestCase
  context "Preference" do
    context "by default" do
      setup do
        @preference = Preference.new
      end

      should "have empty values" do
        assert @preference.attribute.blank?
        assert @preference.owner.blank?
        assert @preference.owner_type.blank?
        assert @preference.group_id.blank?
        assert @preference.group_type.blank?
        assert @preference.value.blank?
        assert @preference.definition.blank?
      end
    end

    context "class" do
      should "be able to split nil groups" do
        assert_equal [nil, nil], Preference.split_group(nil)
      end

      should "be able to split non ActiveRecord groups" do
        assert_equal [nil, "car"], Preference.split_group('car')
      end

      should "be able to split ActiveRecord groups" do
        product = Factory(:product)
        assert_equal [product.id, "Product"], Preference.split_group(product)
      end
    end

    context "with basic group" do
      should "have a group association" do
        preference = Factory(:preference, :group_type => 'car')
        assert_equal "car", preference.group
      end
    end

    context "with ActiveRecord group" do
      should "have a group association" do
        product = Factory(:product)
        preference = Factory(:preference, :group => product)
        assert_equal product, preference.group
      end
    end

    context "in general" do
      should "be valid with valid attributes" do
        preference = Factory.build(:preference)
        assert_valid preference
      end

      should "require an attribute" do
        preference = Factory.build(:preference, :attribute => nil)
        assert(!preference.valid?)
        assert_not_nil preference.errors[:attribute]
      end

      should "have an owner_id and owner_type" do
        preference = Factory.build(:preference, :owner => nil)
        assert(!preference.valid?)
        assert_not_nil preference.errors[:owner_id]
        assert_not_nil preference.errors[:owner_type]
      end

      should "not require a group" do
        preference = Factory.build(:preference, :group => nil)
        assert_valid preference
      end

      should "not require a group_id even when a group_type is specified" do
        preference = Factory.build(:preference, :group => nil, :group_type => 'Product')
        assert_valid preference
      end

      should "require a group type when a group_id is specified" do
        preference = Factory.build(:preference, :group => nil)
        preference.group_id = 1
        assert(!preference.valid?)
        assert_not_nil preference.errors[:group_type]
      end
    end

    context "after being created" do
      setup do
        User.preference :notify_me, :boolean
        @preference = Factory.build(:preference, :attribute => 'notify_me', :value => false)
      end

      should "have correct attributes" do
        assert_not_nil @preference.owner
        assert_not_nil @preference.definition
        assert_not_nil @preference.value
        assert_nil @preference.group
      end

      teardown do
        User.preference_definitions.delete('notify_me')
        User.default_preferences.delete('notify_me')
      end
    end

    context "with boolean attribute" do
      setup do
        User.preference :notify_me, :boolean
        @preference = Factory.build(:preference, :attribute => 'notify_me', :value => nil)
      end

      should "type_cast nil values" do
        assert_nil @preference.value
      end

      should "type_cast numeric values" do
        @preference.value = 0
        assert_equal false, @preference.value
        @preference.value = 1
        assert_equal true, @preference.value
        @preference.value = 3
        assert_equal false, @preference.value
      end

      should "type_cast boolean values" do
        @preference.value = false
        assert_equal false, @preference.value
        @preference.value = true
        assert_equal true, @preference.value
      end

      should "type_cast string values" do
        @preference.value = "false"
        assert_equal false, @preference.value
        @preference.value = "true"
        assert_equal true, @preference.value
        @preference.value = "hello"
        assert_equal false, @preference.value
      end

      teardown do
        User.preference_definitions.delete('notify_me')
        User.default_preferences.delete('notify_me')
      end
    end
  end
end
