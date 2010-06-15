::Hapgood::Attach::Sources::S3.config.merge!(
  :credentials => {:secret_access_key => "v0xaN0sJ1htcnJcPoEqhTwdXdDJlPDrvsfgwXpx0", :access_key_id => "AKIAI2L74WCSSNCGL7VQ"}
)
Hapgood::Attach::Sources::S3.establish_connection!