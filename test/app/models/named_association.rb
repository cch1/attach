class NamedAssociation < ActiveRecord::Base
  belongs_to :user
  belongs_to :attachment
end