#!/usr/bin/osascript 
tell application "Xcode"
	tell project of active project document
		try
			if name is not "SOLogger" then error
		on error
			activate
			display dialog "This script is only applicable to a SOLogger Xcode project."
			return
		end try
		
		try
			make executable with properties {name:"otest", path:"/Developer/Tools/otest"}
		end try
		
		# Configure the arguments and environment variables of the active executable for unit test debugging.
		
		tell executable named "otest"
			# get properties of launch arguments
			# count of launch arguments
			delete (every launch argument)
			make new launch argument with properties {name:"-SenTest All", active:true}
			make new launch argument with properties {name:"$(BUILT_PRODUCTS_DIR)/UnitTests.octest", active:true}
			
			#### DYLD_FALLBACK_FRAMEWORK_PATH needs to be set for Xcode 3 unit testing.
			delete (every environment variable whose name is "DYLD_FALLBACK_FRAMEWORK_PATH")
			make new environment variable with properties {name:"DYLD_FALLBACK_FRAMEWORK_PATH", active:true, value:"$(DEVELOPER_LIBRARY_DIR)/Frameworks:$(DEVELOPER_LIBRARY_DIR)/PrivateFrameworks"}
			
			#### Uncomment the following to configure for debugging unit tests of a framework
			delete (every environment variable whose name is "DYLD_LIBRARY_PATH")
			delete (every environment variable whose name is "DYLD_FRAMEWORK_PATH")
			delete (every environment variable whose name is "OBJC_DISABLE_GC")
			
			make new environment variable with properties {name:"DYLD_LIBRARY_PATH", active:true, value:"$(BUILT_PRODUCTS_DIR)"}
			make new environment variable with properties {name:"DYLD_FRAMEWORK_PATH", active:true, value:"$(BUILT_PRODUCTS_DIR)"}
			make new environment variable with properties {name:"OBJC_DISABLE_GC", active:true, value:"YES"}
			
			
			
			### Uncomment the following to configure for debugging of unit tests injected into an application
			# delete (every environment variable whose name is "XCInjectBundle")
			# delete (every environment variable whose name is "XCInjectBundleInto")
			# delete (every environment variable whose name is "DYLD_INSERT_LIBRARIES")
			# make new environment variable with properties {name:"XCInjectBundle", active:true, value:"UnitTests.octest"}
			# make new environment variable with properties {name:"XCInjectBundleInto", active:true, value:"$(EXECUTABLE_PATH)"}
			# make new environment variable with properties {name:"DYLD_INSERT_LIBRARIES", active:true, value:"$(DEVELOPER_LIBRARY_DIR)/PrivateFrameworks/DevToolsBundleInjection.framework/DevToolsBundleInjection"}
			
		end tell
		
		set active executable to executable named "otest"
		set active target to target named "UnitTests"
		set active build configuration type to build configuration type named "Debug"
	end tell
	
end tell