Gem::Specification.new do |s|
  s.name = 'cron_format'
  s.version = '0.1.15'
  s.summary = 'cron_format'
  s.authors = ['James Robertson']
  s.files = Dir['lib/**/*.rb']
  s.signing_key = '../privatekeys/cron_format.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/cron_format'
  s.required_ruby_version = '>= 2.1.2'
end
