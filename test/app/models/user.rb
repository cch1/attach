class User < ActiveRecord::Base
  has_many :attachments, :as => 'attachee', :dependent => :destroy
end