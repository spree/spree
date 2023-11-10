require 'spec_helper'

module Spree
  module Core
    describe Converters::CSV do
      subject(:csv_converter) { described_class }

      describe ".to_csv" do
        subject(:convert_to_csv) { csv_converter.to_csv(input) }

        let(:input) do
          [
            ["row1a", "row1b", 1, :symbol, "coma,case"],
            ["row2a", "row2b", 2, :symbol, "newline\ncase"],
          ]
        end

        let(:expected_csv_representation) do
          [
            "row1a,row1b,1,symbol,\"coma,case\"\n",
            "row2a,row2b,2,symbol,\"newline\ncase\"\n",
          ].join
        end

        it "returns a valid csv representation" do
          expect(convert_to_csv).to eql expected_csv_representation
        end
      end
    end
  end
end
