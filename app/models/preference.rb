# Represents a preferred value for a particular preference on a model.
# 
# == Targeted preferences
# 
# In addition to simple named preferences, preferences can also be targeted for
# a particular record.  For example, a User may have a preferred color for a
# particular Car.  In this case, the +owner+ is the User, the +preference+ is
# the color, and the +target+ is the Car.  This allows preferences to have a sort
# of context around them.
class Preference < ActiveRecord::Base
  belongs_to  :owner,
                :polymorphic => true
  belongs_to  :preferenced,
                :polymorphic => true
  
  validates_presence_of :attribute,
                        :owner_id,
                        :owner_type
  validates_presence_of :preferenced_id,
                        :preferenced_type,
                          :if => Proc.new {|p| p.preferenced_id? || p.preferenced_type?}
  
  # The definition for the attribute
  def definition
    owner_type.constantize.preference_definitions[attribute] if owner_type
  end
  
  # Typecasts the value depending on the preference definition's declared type
  def value
    value = read_attribute(:value)
    value = definition.type_cast(value) if definition
    value
  end
end
