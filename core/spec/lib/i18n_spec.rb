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
    expect(Spree.normal_t(:foo)).to eql("bar")
    expect(Spree.translate(:foo)).to eql("bar")
  end

  it "translates within the spree scope using a path" do
    allow(Spree).to receive(:virtual_path).and_return('bar')

    expect(Spree.normal_t('.legacy_translation')).to eql("back in the day...")
    expect(Spree.translate('.legacy_translation')).to eql("back in the day...")
  end

  it "raise error without any context when using a path" do
    expect {
      Spree.normal_t('.legacy_translation')
    }.to raise_error(StandardError)

    expect {
      Spree.translate('.legacy_translation')
    }.to raise_error(StandardError)
  end

  it "prepends a string scope" do
    expect(Spree.normal_t(:foo, :scope => "bar")).to eql("bar within bar scope")
  end

  it "prepends to an array scope" do
    expect(Spree.normal_t(:foo, :scope => ["bar"])).to eql("bar within bar scope")
  end

  it "returns two translations" do
    expect(Spree.normal_t([:foo, 'bar.foo'])).to eql(["bar", "bar within bar scope"])
  end

  it "returns reasonable string for missing translations" do
    expect(Spree.t(:missing_entry)).to include("<span")
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
        expect(message).not_to(be_nil, "expected '#{key}' to be missing, but it wasn't.")
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
        expect(Spree.missing_translation_messages).to be_empty
      end

      it "does not break when asked for multiple translations" do
        Spree.t [:foo, 'bar.foo']
        Spree.check_missing_translations
        expect(Spree.missing_translation_messages).to be_empty
      end
    end

    context "unused translations" do
      def assert_unused_translation(key)
        key = key_with_locale(key)
        message = Spree.unused_translation_messages.detect { |m| m == key }
        expect(message).not_to(be_nil, "expected '#{key}' to be unused, but it was used.")
      end

      def assert_used_translation(key)
        key = key_with_locale(key)
        message = Spree.unused_translation_messages.detect { |m| m == key }
        expect(message).to(be_nil, "expected '#{key}' to be used, but it wasn't.")
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
