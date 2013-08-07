require 'hmac/hmac-sha1'

class Integrity

=begin rdoc
  Implement ISO 7064 mod(97,10) check digits to prevent accidental and some
  malicious tampering with data that will be sent to the OSS Census
  collection site.
=end
  def self.add_check_digits(hex_str)
    hex_str_as_base_10_number = hex_str.hex
    check_number = (98 - ((hex_str_as_base_10_number * 100) % 97)) % 97
    result = hex_str_as_base_10_number.to_s + ("%02d" % check_number)

    # make sure we did it right
    raise "add check digits failed" unless result.to_i % 97 == 1

    # convert the big long decimal string into a shorter hexadecimal string
    result.to_i.to_s(16) #.rjust(34, "0")
  end

  def self.iso7064(hex_str)
    add_check_digits( hex_str )
  end

  # create a secure checksum of the results to use as an integrity check
  # on the server side.  Do this by combining the current OpenLogic rules
  # file checksum with a constant to create a secret key.  This secret key
  # is then blended into the results of an SHA1 hash of the file contents
  # to produce a cryptographically strong hash that we can use on the server
  # to make sure the file contents have not been tampered with.  
  # Note that this mechanism can provide only minor defense against a
  # motivated attacker seeking to skew the results of the census.
  
  def self.create_integrity_check(text, universal_rules_md5, version_key)

    secret = universal_rules_md5 + version_key 
    hmac = HMAC::SHA1.hexdigest(secret, text)

    #printf("DEBUG - universal_rules_md5: #{universal_rules_md5}")
    #printf("DEBUG - version_key: #{version_key}")
    #printf("DEBUG - integrity_text size: #{text.size}\n")
    #printf("DEBUG - mac before adding check digits:\n#{mac}, #{mac.size}\n")

    result = add_check_digits(hmac)

    #printf("DEBUG results: #{result}, #{result.size}\n")

    return result
  end

=begin rdoc
  verifies that the integrity check in a results file is correct
=end

  def self.verify_integrity_check(results, version_key)

    rcvd_integrity_check = results.match(/integrity_check:\s*(.*)/)[1]
    universal_rules_md5 = results.match(/universal_rules_md5:\s*(.*)/)[1]

    if ( rcvd_integrity_check == nil || rcvd_integrity_check == "")
      return false        
    end
      
    integrity_check_value = rcvd_integrity_check.hex

    if ( rcvd_integrity_check.size < 60 && rcvd_integrity_check.size > 68 )  
      return false        
    end

    if ( integrity_check_value < 100000000 )
      return false        
    end

    if ( (integrity_check_value % 97) != 1)
      return false        
    end

    #Remove the integrity check from the file and recalculate the integrity check
    integrity_check = create_integrity_check(results.sub(/\n*integrity_check:.*\n/,""),universal_rules_md5, version_key )

    unless rcvd_integrity_check == integrity_check 
      return false        
    end
    
    return true
  end
end
