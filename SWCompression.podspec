Pod::Spec.new do |s|

  s.name         = "SWCompression"
  s.version      = "2.2.1"
  s.summary      = "Framework with implementations in Swift of different (de)compression algorithms"

  s.description  = <<-DESC
  A framework which contains native (written in Swift) implementations of compression algorithms.
  Swift developers currently have access only to various wrappers written in Objective-C
  around system libraries if they want to decompress something. SWCompression allows to do this with pure Swift
  without relying on availability of system libraries.
                   DESC

  s.homepage     = "https://github.com/tsolomko/SWCompression"
  s.documentation_url = "http://tsolomko.github.io/SWCompression"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Timofey Solomko" => "tsolomko@gmail.com" }

  s.ios.deployment_target = "10.1"
  s.osx.deployment_target = "10.12"
  s.tvos.deployment_target = "10.0"
  s.watchos.deployment_target = "3.1"

  s.source       = { :git => "https://github.com/tsolomko/SWCompression.git", :tag => "v#{s.version}" }

  # This is subspec for internal use by other subspecs.
  # It should not be included directly in Podfile.
  s.subspec 'Common' do |sp|
    sp.public_header_files = 'Sources/Service/SWCompression.h'
    sp.source_files  = "Sources/{CheckSums.swift,DataWithPointer.swift,Extensions.swift,Protocols.swift,Service/*.swift,Service/*.h}"
  end

  s.subspec 'Deflate' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.source_files = 'Sources/{Deflate.swift,HuffmanTree.swift,BitToByteWriter.swift}'
  end

  s.subspec 'GZip' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/GZipArchive.swift'
  end

  s.subspec 'Zlib' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/ZlibArchive.swift'
  end

  s.subspec 'BZip2' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.source_files = 'Sources/{BZip2.swift,HuffmanTree.swift}'
  end

  s.subspec 'LZMA' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.source_files = 'Sources/LZMA*.swift'
  end

  s.subspec 'XZ' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.dependency 'SWCompression/LZMA'
    sp.source_files = 'Sources/XZArchive.swift'
  end

  s.subspec 'ZIP' do |sp|
    sp.dependency 'SWCompression/Common'
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/ZipContainer.swift'
  end

end
