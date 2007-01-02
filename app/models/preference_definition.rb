#
class PreferenceDefinition < ActiveRecord::Base
  has_many              :preferences,
                          :foreign_key => 'definition_id'
  
  validates_presence_of :name
  validates_format_of   :name,
                          :with => /\w/
  
  #
  def default_value(preferenced_type = nil)
    self.class.parent.default_value_for_preference(name, preferenced_type)
  end
  
  #
  def data_type(preferenced_type = nil)
    self.class.parent.data_type_for_preference(name, preferenced_type)
  end
  
  #
  def possible_values(preferenced_type = nil)
    self.class.parent.possible_values_for_preference(name, preferenced_type)
  end
  
  #
  def valid_preference?(preferenced_type = nil)
    self.class.parent.valid_preference?(name, preferenced_type)
  end
  
  #
  def valid_value?(value)
    possible_values.nil? || possible_values.empty? || possible_values.include?(value)
  end
end