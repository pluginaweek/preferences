class User < ActiveRecord::Base
  preference :hot_salsa
  preference :dark_chocolate, :default => true
  preference :color, :string
  preference :car, :integer
  preference :language, :string, :default => 'English'
end
