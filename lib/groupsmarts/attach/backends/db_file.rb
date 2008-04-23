class DbFile < ActiveRecord::Base
  belongs_to :attachment

  # Summarize blob data
  def inspect
    self.attributes(:except => :data).merge({:data => (self.data.nil? ? nil : "#{self.data.size/1024}K blob")}).inspect
  end
end