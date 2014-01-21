require 'spec_helper'

module Spree
  describe Migrations do
    let(:app_migrations) { [".", "34_add_title.rb", "52_add_text.rb"] }
    let(:engine_migrations) { [".", "334_create_orders.spree.rb", "777_create_products.spree.rb"] }

    let(:config) { double("Config", root: "dir") }

    subject { described_class.new(config, "spree")  }

    before do
      expect(File).to receive(:exists?).with("config/spree.yml").and_return true
      expect(File).to receive(:directory?).with("db/migrate").and_return true
    end

    it "warns about missing migrations" do
      expect(Dir).to receive(:entries).with("db/migrate").and_return app_migrations
      expect(Dir).to receive(:entries).with("dir/db/migrate").and_return engine_migrations

      silence_stream(STDOUT) {
        expect(subject.check).to eq true
      }
    end

    context "no missing migrations" do
      it "says nothing" do
        expect(Dir).to receive(:entries).with("dir/db/migrate").and_return engine_migrations
        expect(Dir).to receive(:entries).with("db/migrate").and_return (app_migrations + engine_migrations)
        expect(subject.check).to eq nil
      end
    end
  end
end
