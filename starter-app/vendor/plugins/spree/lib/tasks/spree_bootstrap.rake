namespace :spree do
  desc "Loads admin user and other structural data required by RC.  You must run this task before using RC."
  task :bootstrap => :environment do
    # create the default admin user
    User.create(:login => 'admin',
                :email => 'admin@changeme.com', 
                :salt => '7e3041ebc2fc05a40c60028e2c4901a81035d3cd', 
                :crypted_password => '00742970dc9e6319f8019fd54864d3ea740f04b1',
                :password => 'test', 
                :password_confirmation => 'test')
    
    # create an admin role and and assign the default admin user to the role
    role = Role.create(:name => 'admin')
    user = User.find(1)
    user.roles << role
    user.save!    

    # create some built-in tax treatments to choose from
    TaxTreatment.create(:name => "Non taxable")
    TaxTreatment.create(:name => "U.S. Sales Tax")
    
    puts "Spree bootstrap process completed."
  end
end