class User < ActiveRecord::Base
  has_many :attachments
end