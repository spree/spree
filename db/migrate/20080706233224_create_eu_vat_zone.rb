class CreateEuVatZone < ActiveRecord::Migration
  def self.up
    # create an EU VAT zone (for optional use with EU VAT)
    zone = Zone.create :name => "EU_VAT", :description => "Countries that make up the EU VAT zone."
    countries = []
    %w[AT BE BG CY CZ DK EE FI FR DE HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE GB].each do |iso|
      zone.members << Country.find_by_iso(iso)
    end
  end

  def self.down
  end
end
