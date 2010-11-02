# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# This Mime type is included to ensure at least one is unprocessable by the image processor
Mime::Type.register 'application/octet-stream', :bin, %w(application/binary)

# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register_alias "text/html", :iphone
Mime::Type.register 'application/xrds+xml', :xrds
Mime::Type.register 'application/pdf', :pdf
Mime::Type.register_alias "text/html", :openid
# Image Types
Mime::Type.register 'image/jpeg', :jpg, ['image/jpg'], ['jpeg']
Mime::Type.register 'image/pjpeg', :pjpg
Mime::Type.register 'image/bmp', :bmp
Mime::Type.register 'image/png', :png
Mime::Type.register 'image/gif', :gif
# Adobe Flash Video Player types (from http://en.wikipedia.org/wiki/Flash_Video)
Mime::Type.register 'application/x-shockwave-flash', :swf # for proprietary player
Mime::Type.register 'video/x-flv', :flv # for legacy, proprietary video
Mime::Type.register 'video/mp4', :mp4, [], %w(f4v f4p)
Mime::Type.register 'audio/mp4', :mp4a, [], %w(f4a f4b)
