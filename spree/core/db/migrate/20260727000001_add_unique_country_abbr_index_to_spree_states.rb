class AddUniqueCountryAbbrIndexToSpreeStates < ActiveRecord::Migration[7.2]
  def up
    remove_duplicate_states!

    add_index :spree_states, [:country_id, :abbr],
              unique: true,
              name: 'index_spree_states_on_country_id_and_abbr'
  end

  def down
    remove_index :spree_states, name: 'index_spree_states_on_country_id_and_abbr'
  end

  private

  # `Spree::Seeds::States` used a plain `insert_all` for province-level
  # countries, so re-running the seeds duplicated their states. Keep the oldest
  # row of each group — addresses point at it — and drop the rest.
  def remove_duplicate_states!
    duplicated = Spree::State.group(:country_id, :abbr).having('COUNT(*) > 1').pluck(:country_id, :abbr)

    duplicated.each do |country_id, abbr|
      ids = Spree::State.where(country_id: country_id, abbr: abbr).order(:id).pluck(:id)
      keeper = ids.shift

      Spree::Address.where(state_id: ids).update_all(state_id: keeper) if ids.any?
      Spree::State.where(id: ids).delete_all
    end
  end
end
