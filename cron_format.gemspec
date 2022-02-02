Gem::Specification.new do |s|
  s.name = 'cron_format'
  s.version = '0.7.0'
  s.summary = 'Accepts a cron expression and outputs the relative ' + 
      'time (e.g. 0 7 1 1 * * => 2019-01-01 07:00:00 +0000'
  s.authors = ['James Robertson']
  s.files = Dir['lib/cron_format.rb']
  s.add_runtime_dependency('c32', '~> 0.3', '>=0.3.0')
  s.signing_key = '../privatekeys/cron_format.pem'
  s.cert_chain  = ['gem-public_cert.pem']  
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/cron_format'
  s.required_ruby_version = '>= 2.1.2'
end
