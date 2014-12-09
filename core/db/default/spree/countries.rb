require 'carmen'

connection = ActiveRecord::Base.connection
case connection.adapter_name
when "PostgreSQL"
  country_inserts = []
  country_values = -> do
    Carmen::Country.all.each do |country|
      country_inserts << [country.name, country.alpha_3_code, country.alpha_2_code,
                          country.name.upcase, country.numeric_code, "#{country.subregions?}"]
    end
    country_inserts.map do |country_insert|
      country_insert.map do |country_value|
        country_value.gsub("'", "''")
      end.join("', '")
    end.join("'), ('")
  end

  connection.execute <<-SQL
    INSERT INTO spree_countries ("name", "iso3", "iso", "iso_name", "numcode", "states_required")
    VALUES ('#{country_values.call}');
  SQL
else
  countries = []
  Carmen::Country.all.each do |country|
    countries << {
      name: country.name,
      iso3: country.alpha_3_code,
      iso: country.alpha_2_code,
      iso_name: country.name.upcase,
      numcode: country.numeric_code,
      states_required: country.subregions?
    }
  end

  ActiveRecord::Base.transaction do
    Spree::Country.create!(countries)
  end
end

Spree::Config[:default_country_id] = Spree::Country.find_by(name: "United States").id
