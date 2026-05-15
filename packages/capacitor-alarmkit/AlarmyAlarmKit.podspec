Pod::Spec.new do |s|
  s.name = 'AlarmyAlarmKit'
  s.version = '0.0.1'
  s.summary = 'Local Capacitor bridge for AlarmKit.'
  s.license = 'MIT'
  s.homepage = 'https://github.com/Krazel/Alarmy'
  s.author = 'Krazel'
  s.source = { :path => '.' }
  s.source_files = 'ios/Plugin/**/*.{swift,h,m,c,cc,mm,cpp}'
  s.ios.deployment_target = '16.0'
  s.dependency 'Capacitor'
  s.swift_version = '5.9'
end
