

Pod::Spec.new do |s|


  s.name         = "AltBeacon"
  s.version      = "0.3"
  s.summary      = "AltBeacon is an alternative to iBeacon that allows iOS devices to be advertised in the background."

  s.description  = <<-DESC
                   AltBeacon is an alternative to iBeacon that allows iOS devices to be advertised in the background, which is not currently possible with iBeacon. **It is based on the open source project Vinicity (thanks Ben Ford)** https://github.com/Instrument/Vicinity. In addition to the great job done in Vicinity, AltBeacons adds the possibility to detect many AltBeacons with different UUIDS and the accuracy of the range was improved. It is important to notice that by advertising in the background a whole new range of use cases are possible that require people to interact with nearby people, for example a messaging app for nearby people. We are currenlty using this framework to develop a product that will be soon in the AppStore. 
                   DESC

  s.homepage     = "https://github.com/CharruaLabs/AltBeacon"

  #s.license      = "MIT (example)"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  
  s.author             = { "Martin Palatnik" => "marpal@gmail.com" }
  s.social_media_url   = "http://twitter.com/mpalatnik"

  s.platform     = :ios, "6.0"

  s.source       = { :git => "https://github.com/CharruaLabs/AltBeacon.git", :tag => s.version.to_s } 

  s.source_files  = "AltBeacon/Source/**/*.{h,m}"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

  # s.framework  = "SomeFramework"
  # s.frameworks = "SomeFramework", "AnotherFramework"

  # s.library   = "iconv"
  # s.libraries = "iconv", "xml2"


  s.requires_arc = true

end
