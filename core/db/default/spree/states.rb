ActiveRecord::Base.transaction do
  Spree::Country.all.each do |country|
    carmen_country = Carmen::Country.named(country.name)
    @states ||= []
    if carmen_country.subregions?
      carmen_country.subregions.each do |subregion|
        @states << {
          name: subregion.name,
          abbr: subregion.code,
          country: country
        }
      end
    end
  end
  Spree::State.create!(@states)
end
