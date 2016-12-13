Pod::Spec.new do |s|
s.name         = "MLImageBrowser"
s.version      = "0.1.0"
s.summary      = "Simple image browser"

s.homepage     = 'https://github.com/molon/MLImageBrowser'
s.license      = { :type => 'MIT'}
s.author       = { "molon" => "dudl@qq.com" }

s.source       = {
:git => "https://github.com/molon/MLImageBrowser.git",
:tag => "#{s.version}"
}

s.platform     = :ios, '7.0'
s.public_header_files = 'Classes/**/*.h'
s.source_files  = 'Classes/**/*.{h,m,c}'
s.requires_arc  = true

end
