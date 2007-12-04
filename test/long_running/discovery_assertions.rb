module DiscoveryAssertions
  
  def assert_was_found(name="", version="", found_packages=Array.new)
    val = false
    found_packages.each { |package|
      if (package.name == name && package.version == version) then
        val = true
        break
      end
    }
    assert(val, "Did not find expected package: name = '#{name}', version='#{version}'")
  end

  def assert_was_found_in(name="", version="", expected_location="", found_packages=Array.new)
    found_package = false
    found_in_expected_location = false
    found_at_ends_with = ""
    found_packages.each { |package|
      if (package.name == name && package.version == version) then 
        found_package = true
        found_at = package.found_at
        found_at_ends_with = found_at[(found_at.size - expected_location.size)..(found_at.size)]
        if (found_at_ends_with == expected_location) then
          found_in_expected_location = true
          break
        else
          next
        end
      end
    }
    fail_msg = ""
    if (!found_package) then
      fail_msg = "Did not find expected package: name = '#{name}', version='#{version}'"
    elsif (!found_in_expected_location)
      fail_msg = "The expected package: (name = '#{name}', version='#{version}') was found, but not in the expected location '#{expected_location}'."
    end
    
    assert(found_package && found_in_expected_location, fail_msg)
  end
  
=begin rdoc
  Asserts that a package with 'name' and 'version' was found in the 'location' parameter.
  This is all it asserts.  It does not assert that the package (again, name + version) was NOT found
  somewhere else.  If you're looking for this type of functionality, see 'assert_was_found_in_locations'.
=end    
  def assert_was_not_found_in(name="", version="", location="", found_packages=Array.new)
    found_package = false
    found_in_location = false
    found_at_ends_with = ""
    found_packages.each { |package|
      if (package.name == name && package.version == version) then 
        found_package = true
        found_at = package.found_at
        found_at_ends_with = found_at[(found_at.size - location.size)..(found_at.size)]
        if (found_at_ends_with == location) then
          found_in_location = true
          break
        else
          next
        end
      end
    }
    if (found_package && found_in_location) then
      assert(false, "Found a package (name = '#{name}', version='#{version}') where it should NOT have been found (#{location}).")
    else 
      assert(true, "All is well. The package was not found where you said it was not supposed to be found.")
    end
  end
  
=begin rdoc
  Asserts that a package with 'name' and 'version' was found in the expected locations.  
  This is a much more restrictive and exact test than 'assert_was_found_in' as this asserts 
  that the package version was found in the exact locations passed in as an argument, no more, no less.
  - If the package was not found in all of the expected locations, the assertion will fail.
  - If the package was found in more than the expected locations, the assertion will fail.
=end  
  def assert_was_found_in_locations(name="", version="", expected_locations=[""], found_packages=Array.new)
    if (expected_locations.class.to_s == "String") then expected_locations = [expected_locations] end
    fp_subset = Array.new
    found_packages.each do |fp|
      if (fp.name == name && fp.version == version) then 
        fp_subset << fp
      end
    end
      
    val = true
    if (fp_subset.size != expected_locations.size) then
      val = false
    end
      
    if (val) then
      expected_locations.each do |loc|
        loc_found = false
        fp_subset.each do |fp|
          found_at = fp.found_at
          found_at_ends_with = found_at[(found_at.size - loc.size)..(found_at.size)]
          if (found_at_ends_with == loc) then
            loc_found = true
            break
          else
            next
          end
        end # of fp_subset.each
        if (!loc_found) then
          val = false
          break
        end
      end # of expected_locations.each
    end # of if(val)
      
    actual_locations = fp_subset.collect {|p| p.found_at}
    assert(val, "Expected to find package (name = '#{name}'; version = '#{version}') in these locations: #{expected_locations.inspect}. Actually found it in these locations: #{actual_locations.inspect}.")      
  end
    
end