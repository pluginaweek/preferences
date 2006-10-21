#
#
class Preference < ActiveRecord::Base
  belongs_to            :definition,
                          :class_name => 'PreferenceDefinition',
                          :foreign_key => 'definition_id'
  belongs_to            :preferenced, :polymorphic => true
  
  validates_presence_of :definition_id,
                        :owner_id,
                        :preferenced_id,
                        :preferenced_type
                        
  delegate              :default_value,
                        :data_type,
                        :possible_values,
                          :to => :definition
  
  #
  #
  def validate
    @errors.add 'preferenced_type', 'is not a valid type' unless definition.valid_preference?(preferenced_type)
    @errors.add 'value', "must be #{possible_values.to_sentence(:connector => 'or')}" unless definition.valid_value?(value)
  end
end