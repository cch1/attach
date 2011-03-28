::Hapgood::Attach::Sources::S3.config.merge!(
  :credentials => {:secret_access_key => AppConfig.s3[:secret_access_key], :access_key_id => AppConfig.s3[:access_key_id]},
  :access => :public_read
)
Hapgood::Attach::Sources::S3.establish_connection!