SUMMARY
=======

Spree is a complete open source commerce solution for Ruby on Rails.  It was developed by Sean Schofield under the original name of Rails Cart before changing its name to Spree.

QUICK START
===========

1.) Install spree Gem

$ sudo gem install spree

2.) Create Spree Application

$ spree app_name

3.) Create MySQL Database

mysql> create database spree_dev;
mysql> grant all privileges on spree_dev.* to 'spree'@'localhost' identified by 'spree';
mysql> flush privileges;

4.) Migrations

$ cd app_name
$ rake db:migrate

5.) Bootstrap

Spree requires an admin user and a few other pieces of structural data to be loaded into your database.

rake spree:bootstrap

6.) Sample Data (Optional)

Optionally load some sample data so you have something to look at.

rake spree:sample_data

7.) Launch Application

Browse Store

http://localhost:xxxx/store

Admin Interface (user: admin password: test)

http://localhost:xxxx/admin     

