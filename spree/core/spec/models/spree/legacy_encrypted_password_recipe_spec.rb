require 'spec_helper'

# Proves the Path B upgrade recipe (docs/plans/6.0-platform-auth.md): a custom
# Spree.customer_class that keeps its legacy Devise `encrypted_password` column
# works with `has_secure_password` via `alias_attribute` — no data migration and
# no gem concern. If this breaks, the documented recipe is wrong.
describe 'Legacy encrypted_password bridge', type: :model do
  before(:all) do
    ActiveRecord::Base.connection.create_table :legacy_recipe_users, force: true do |t|
      t.string :email
      t.string :encrypted_password
      t.timestamps
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :legacy_recipe_users, if_exists: true
  end

  let(:model) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'legacy_recipe_users'
      has_secure_password validations: false
      alias_attribute :password_digest, :encrypted_password
    end
  end

  it 'hashes a new password into the legacy encrypted_password column' do
    user = model.create!(email: 'legacy@example.com', password: 'secret123')

    expect(user.encrypted_password).to be_present
    expect(user.password_digest).to eq(user.encrypted_password)
  end

  it 'authenticates against the aliased column' do
    user = model.create!(email: 'legacy@example.com', password: 'secret123')

    expect(user.authenticate('secret123')).to be_truthy
    expect(user.authenticate('wrong')).to be(false)
  end

  it 're-authenticates a reloaded record' do
    model.create!(email: 'legacy2@example.com', password: 'hunter2!')

    expect(model.find_by(email: 'legacy2@example.com').authenticate('hunter2!')).to be_truthy
  end
end
