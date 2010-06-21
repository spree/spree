require 'test_helper'

class PreferenceDefinitionTest < ActiveSupport::TestCase
  context "PreferenceDefinition" do
    context  "by default" do
      setup do
        @definition = Spree::Preferences::PreferenceDefinition.new(:notifications)
      end

      should "have an attribute" do
        assert_equal "notifications", @definition.attribute
      end

      should "not have a default value" do
        assert_nil @definition.default_value
      end

      should "type_cast values as booleans" do
        assert_equal nil, @definition.type_cast(nil)
        assert_equal true, @definition.type_cast(true)
        assert_equal false, @definition.type_cast(false)
        assert_equal false, @definition.type_cast(0)
        assert_equal true, @definition.type_cast(1)
      end
    end

    context "with invalid options specified" do
      should "raise an ArgumentError exception " do
        assert_raise ArgumentError do
          Spree::Preferences::PreferenceDefinition.new(:notifications, :invalid => true)
        end
      end
    end

    context "with :any type" do
      setup do
        @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :any)
      end

      should "not type_cast" do
        assert_equal nil, @definition.type_cast(nil)
        assert_equal 0, @definition.type_cast(0)
        assert_equal 1, @definition.type_cast(1)
        assert_equal false, @definition.type_cast(false)
        assert_equal true, @definition.type_cast(true)
        assert_equal '', @definition.type_cast('')
        assert_equal 'Chunky bacon', @definition.type_cast('Chunky bacon')
      end

      should "query false if value is nil" do
        assert_equal false, @definition.query(nil)
      end

      should "query true if value is zero" do
        assert_equal true, @definition.query(0)
      end

      should "query true if value es not zero" do
        assert_equal true, @definition.query(-1)
        assert_equal true, @definition.query(1)
      end

      should "query false if value is blank" do
        assert_equal false, @definition.query('')
      end

      should "query true if value is not blank" do
        assert_equal true, @definition.query('hello')
      end
    end

    context "with :boolean default value" do
      should "type_cast default values" do
        definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :boolean, :default => 1)
        assert_equal true, definition.default_value
      end
    end


    context "with :boolean type" do
      setup do
        @definition = Spree::Preferences::PreferenceDefinition.new(:notifications)
      end

      should "not type_cast if value is nil" do
        assert_equal nil, @definition.type_cast(nil)
      end

      should "type_cast to false if value is not 1" do
        assert_equal false, @definition.type_cast(0)
        assert_equal false, @definition.type_cast(3)
      end

      should "type_cast to true if value is 1" do
        assert_equal true, @definition.type_cast(1)
      end

      should "type_cast to ture if value is true string" do
        assert_equal true, @definition.type_cast('true')
      end

      should "type_cast to false if value is not true string" do
        assert_equal false, @definition.type_cast('false')
        assert_equal false, @definition.type_cast('hola')
      end

      should "query false if value is nil" do
        assert_equal false, @definition.query(nil)
      end

      should "query true if value is 1" do
        assert_equal true, @definition.query(1)
      end

      should "query false if value es not 1" do
        assert_equal false, @definition.query(-1)
        assert_equal false, @definition.query(0)
      end

      should "query true if value is true string" do
        assert_equal true, @definition.query('true')
      end

      should "query false if value is not true string" do
        assert_equal false, @definition.query('')
      end
    end

    context "with Numeric type" do
      setup do
        @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :integer)
      end

      should "type_cast true to integer" do
        assert_equal 1, @definition.type_cast(true)
      end

      should "type_cast false to integer" do
        assert_equal 0, @definition.type_cast(false)
      end

      should "type_cast string to integer" do
        assert_equal 0, @definition.type_cast('hello')
        assert_equal 1, @definition.type_cast('1')
      end

      should "query false if value is nil" do
        assert_equal false, @definition.query(nil)
      end

      should "query true if value is 1" do
        assert_equal true, @definition.query(1)
      end

      should "query false if value is 0" do
        assert_equal false, @definition.query(0)
      end
    end

    context "with String type" do
      setup do
        @definition = Spree::Preferences::PreferenceDefinition.new(:notifications, :string)
      end

      should "type_cast integer to strings" do
        assert_equal '1', @definition.type_cast('1')
      end

      should "not type_cast booleans" do
        assert_equal true, @definition.type_cast(true)
        assert_equal false, @definition.type_cast(false)
      end

      should "query true if value is 1" do
        assert_equal true, @definition.query(1)
      end

      should "query true if value is zero" do
        assert_equal true, @definition.query(0)
      end

      should "query false if value is blank" do
        assert_equal false, @definition.query('')
      end

      should "query true if value is not blank" do
        assert_equal true, @definition.query('hello')
      end
    end

  end
end
