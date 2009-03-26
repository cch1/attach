ActiveRecord::Schema.define(:version => 0) do
  create_table :attachments, :force => true do |t|
    t.string :uri, :limit => 255
    t.string :content_type, :limit => 35
    t.binary :digest
    t.integer :size
    t.string :aspect
    t.string :filename, :limit => 75
    t.string :metadata, :limit => 2048
    t.string :description, :limit => 128
    t.integer :parent_id
    t.timestamps
  end

  create_table "attachment_blobs", :force => true do |t|
    t.binary "blob", :null => false
    t.integer "attachment_id", :null => false
  end
end