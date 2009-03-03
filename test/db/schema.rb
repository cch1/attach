ActiveRecord::Schema.define(:version => 0) do
  create_table :users, :force => true do |t|
    t.string "login", :limit => 80
    t.boolean "verified", :default => false, :null => false
    t.string "security_token", :limit => 128
    t.datetime "token_expiry"
    t.datetime "logged_in_at"
    t.boolean "deleted", :default => false, :null => false
    t.datetime "delete_after"
    t.timestamps
  end

  create_table :attachments, :force => true do |t|
    t.string :uri, :limit => 150
    t.string :content_type, :limit => 35
    t.binary :digest
    t.integer :size
    t.string :aspect
    t.string :filename, :limit => 75
    t.string :metadata, :limit => 2048
    t.string :description, :limit => 128
    t.integer :parent_id
    t.integer :attachee_id, :null => false
    t.string :attachee_type, :limit => 25, :null => false
    t.timestamps
  end

  create_table "attachment_blobs", :force => true do |t|
    t.binary "blob", :null => false
    t.integer "attachment_id", :null => false
  end
end