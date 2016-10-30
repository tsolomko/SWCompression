Pod::Spec.new do |s|

  s.name         = "SWCompression"
  s.version      = "1.0.0"
  s.summary      = "Framework with implementations in Swift of different (de)compression algorithms"

  s.description  = <<-DESC
  A framework which contains native (written in Swift) implementations of compression algorithms.
  Swift developers currently have access only to various wrappers written in Objective-C
  around system libraries if they want to decompress something. SWCompression allows to do this with pure Swift
  without relying on availability of system libraries.
                   DESC

  s.homepage     = "https://github.com/tsolomko/SWCompression"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Timofey Solomko" => "tsolomko@gmail.com" }

  s.source       = { :git => "https://github.com/tsolomko/SWCompression.git", :tag => "v#{s.version}" }

  s.source_files  = "Sources"

end
