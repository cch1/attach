ActiveRecord::Schema.define(:version => Time.now.utc.strftime("%Y%m%d%H%M%S")) do
  create_table :attachments, :force => true do |t|
    t.string :uri, :limit => 255
    t.string :content_type, :limit => 35
    t.binary :digest
    t.integer :size
    t.string :filename, :limit => 75
    t.string :metadata, :limit => 2048
    t.string :description, :limit => 128
    t.timestamps
  end

  create_table :attachment_blobs, :force => true do |t|
    t.binary :blob, :null => false
  end

  create_table :users, :force => true do |t|
    t.string :login, :null => false
  end

  create_table :named_associations, :force => true do |t|
    t.references :user
    t.references :attachment
    t.string :name
  end
end