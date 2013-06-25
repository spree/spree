require 'rspec/expectations'
require 'spree/i18n'
require 'spree/testing_support/i18n'

describe "i18n" do
  before do
    I18n.backend.store_translations(:en,
    {
      :spree => {
        :foo => "bar",
        :bar => {
          :foo => "bar within bar scope",
          :invalid => nil,
          :legacy_translation => "back in the day..."
        },
        :invalid => nil,
        :legacy_translation => "back in the day..."
      }
    })
  end

  it "translates within the spree scope" do
    Spree.normal_t(:foo).should eql("bar")
    Spree.translate(:foo).should eql("bar")
  end

  it "translates within the spree scope using a path" do
    Spree.stub(:virtual_path).and_return('bar')

    Spree.normal_t('.legacy_translation').should eql("back in the day...")
    Spree.translate('.legacy_translation').should eql("back in the day...")
  end

  it "raise error without any context when using a path" do
    expect {
      Spree.normal_t('.legacy_translation')
    }.to raise_error

    expect {
      Spree.translate('.legacy_translation')
    }.to raise_error
  end

  it "prepends a string scope" do
    Spree.normal_t(:foo, :scope => "bar").should eql("bar within bar scope")
  end

  it "prepends to an array scope" do
    Spree.normal_t(:foo, :scope => ["bar"]).should eql("bar within bar scope")
  end

  it "returns two translations" do
    Spree.normal_t([:foo, 'bar.foo']).should eql(["bar", "bar within bar scope"])
  end

  it "returns reasonable string for missing translations" do
    Spree.t(:missing_entry).should include("<span")
  end

  context "missed + unused translations" do
    def key_with_locale(key)
      "#{key} (#{I18n.locale})"
    end

    before do
      Spree.used_translations = []
    end

    context "missed translations" do
      def assert_missing_translation(key)
        key = key_with_locale(key)
        message = Spree.missing_translation_messages.detect { |m| m == key }
        message.should_not(be_nil, "expected '#{key}' to be missing, but it wasn't.")
      end

      it "logs missing translations" do
        Spree.t(:missing, :scope => [:else, :where])
        Spree.check_missing_translations
        assert_missing_translation("else")
        assert_missing_translation("else.where")
        assert_missing_translation("else.where.missing")
      end

      it "does not log present translations" do
        Spree.t(:foo)
        Spree.check_missing_translations
        Spree.missing_translation_messages.should be_empty
      end

      it "does not break when asked for multiple translations" do
        Spree.t [:foo, 'bar.foo']
        Spree.check_missing_translations
        Spree.missing_translation_messages.should be_empty
      end
    end

    context "unused translations" do
      def assert_unused_translation(key)
        key = key_with_locale(key)
        message = Spree.unused_translation_messages.detect { |m| m == key }
        message.should_not(be_nil, "expected '#{key}' to be unused, but it was used.")
      end

      def assert_used_translation(key)
        key = key_with_locale(key)
        message = Spree.unused_translation_messages.detect { |m| m == key }
        message.should(be_nil, "expected '#{key}' to be used, but it wasn't.")
      end

      it "logs translations that aren't used" do
        Spree.check_unused_translations
        assert_unused_translation("bar.legacy_translation")
        assert_unused_translation("legacy_translation")
      end

      it "does not log used translations" do
        Spree.t(:foo)
        Spree.check_unused_translations
        assert_used_translation("foo")
      end
    end
  end
end
