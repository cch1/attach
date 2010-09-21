::Hapgood::Attach::Sources::S3.config.merge!(
  :credentials => {:secret_access_key => "RYr2j1lgAmOSO8aJJCE7CnN/CjL1Xdykasixihy/", :access_key_id => "AKIAJAB7ETCUXOW3OWKA"},
  :access => :public_read
)
Hapgood::Attach::Sources::S3.establish_connection!