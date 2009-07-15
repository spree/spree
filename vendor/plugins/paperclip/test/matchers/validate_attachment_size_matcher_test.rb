require 'test/helper'

class ValidateAttachmentSizeMatcherTest < Test::Unit::TestCase
  context "validate_attachment_size" do
    setup do
      reset_table("dummies") do |d|
        d.string :avatar_file_name
      end
      @dummy_class = reset_class "Dummy"
      @dummy_class.has_attached_file :avatar
    end

    context "of limited size" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar).in(256..1024) }

      should "reject a class with no validation" do
        assert_rejects @matcher, @dummy_class
      end

      should "reject a class with a validation that's too high" do
        @dummy_class.validates_attachment_size :avatar, :in => 256..2048
        assert_rejects @matcher, @dummy_class
      end

      should "reject a class with a validation that's too low" do
        @dummy_class.validates_attachment_size :avatar, :in => 0..1024
        assert_rejects @matcher, @dummy_class
      end

      should "accept a class with a validation that matches" do
        @dummy_class.validates_attachment_size :avatar, :in => 256..1024
        assert_accepts @matcher, @dummy_class
      end
    end

    context "validates_attachment_size with infinite range" do
      setup{ @matcher = self.class.validate_attachment_size(:avatar) }

      should "accept a class with an upper limit" do
        @dummy_class.validates_attachment_size :avatar, :less_than => 1
        assert_accepts @matcher, @dummy_class
      end

      should "accept a class with no upper limit" do
        @dummy_class.validates_attachment_size :avatar, :greater_than => 1
        assert_accepts @matcher, @dummy_class
      end
    end
  end
end
