class User < ActiveRecord::Base
  has_many :named_associations
  has_many :attachments, :through => :named_associations
end