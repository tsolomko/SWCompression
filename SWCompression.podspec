Pod::Spec.new do |s|

  s.name         = "SWCompression"
  s.version      = "3.2.0-test"
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

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source       = { :git => "https://github.com/tsolomko/SWCompression.git", :tag => "v#{s.version}" }

  # This is subspec for internal use by other subspecs.
  # It should not be included directly in Podfile.

  s.subspec 'Deflate' do |sp|
    sp.source_files = 'Sources/{Deflate,DeflateCompression,DeflateError,Extensions,Protocols,DataWithPointer,BitReader,HuffmanTree,BitWriter,CheckSums}.swift'
  end

  s.subspec 'GZip' do |sp|
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/{GzipArchive,GzipHeader,GzipError,CheckSums}.swift'
  end

  s.subspec 'Zlib' do |sp|
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/{ZlibArchive,ZlibHeader,ZlibError,CheckSums}.swift'
  end

  s.subspec 'BZip2' do |sp|
    sp.source_files = 'Sources/{BZip2,BZip2Error,Extensions,Protocols,CheckSums,DataWithPointer,BitReader,HuffmanTree,BitWriter}.swift'
    sp.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-DSWCOMP_ZIP_POD_BZ2' }
  end

  s.subspec 'LZMA' do |sp|
    sp.source_files = 'Sources/{LZMA*,Extensions,Protocols,DataWithPointer}.swift'
    sp.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-DSWCOMP_ZIP_POD_LZMA' }
  end

  s.subspec 'XZ' do |sp|
    sp.dependency 'SWCompression/LZMA'
    sp.source_files = 'Sources/{XZArchive,XZError,CheckSums}.swift'
  end

  s.subspec 'ZIP' do |sp|
    sp.dependency 'SWCompression/Deflate'
    sp.source_files = 'Sources/{Zip*,CheckSums}.swift'
    sp.pod_target_xcconfig = { 'OTHER_SWIFT_FLAGS' => '-DSWCOMP_ZIP_POD_BUILD' }
  end

  s.subspec 'TAR' do |sp|
    sp.source_files = 'Sources/{Tar*,Extensions,Protocols,DataWithPointer}.swift'
  end

end
