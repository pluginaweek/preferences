class CreatePreferences < ActiveRecord::Migration
  def self.up
    create_table :preferences do |t|
      t.column :definition_id,    :integer,   :null => false, :unsigned => true,  :references => :preference_definitions
      t.column :owner_id,         :integer,   :null => false, :unsigned => true,  :references => nil
      t.column :preferenced_type, :string
      t.column :preferenced_id,   :integer,                   :unsigned => true,  :references => nil
      t.column :value,            :string
      t.column :type,             :string,    :null => false
      t.column :created_at,       :timestamp, :null => false
      t.column :updated_at,       :datetime,  :null => false
    end
    add_index :preferences, [:type, :definition_id, :owner_id, :preferenced_type, :preferenced_id], :unique => true, :name => 'preferences_definition_id_owner_id_preferenced'
  end
  
  def self.down
    drop_table_if_exists :preferences
  end
end
