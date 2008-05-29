
# figure out if SHA256 is available through either the 
# Ruby 'openssl' module or through Java via JRuby

begin
  # if we're running under JRuby, we can still make SHA256 work
  require 'java'
  JAVA_SHA256_AVAILABLE = true
rescue LoadError
  JAVA_SHA256_AVAILABLE = false
end

# if we're using Java, use its SHA256.  The pure ruby link or even jruby link with native OpenSSL on 
# host machine may not work - 0.9.7 doesn't have SHA256 in it for example.  So, don't rely on native
# openssl if this is running under jruby

if JAVA_SHA256_AVAILABLE
  RUBY_SHA256_AVAILABLE = false
else
  begin
    # not all ruby installs and builds contain openssl, so degrade
    # gracefully if it can't be pulled in.
    require 'openssl'
    
    # this line will throw an uninitialized constant exception for < 0.9.8 openssl since SHA256 doesn't exist in 0.9.7
    OpenSSL::Digest::SHA256.new
    RUBY_SHA256_AVAILABLE = true
    
  rescue LoadError => e
    RUBY_SHA256_AVAILABLE = false
  end
end

# we can use SHA256 if it's available through either Ruby or Java
SHA256_AVAILABLE = RUBY_SHA256_AVAILABLE || JAVA_SHA256_AVAILABLE

class Integrity
  
  def initialize
  end

  def self.sha256_available?
		return SHA256_AVAILABLE
  end

  def self.jruby_sha256_available?
     return JAVA_SHA256_AVAILABLE
  end

  def self.ruby_sha256_available?
     return RUBY_SHA256_AVAILABLE
  end

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
  # is then blended into the results of an SHA256 hash of the file contents
  # to produce a cryptographically strong hash that we can use on the server
  # to make sure the file contents have not been tampered with.  
  # Note that this mechanism can provide only minor defense against a
  # motivated attacker seeking to skew the results of the census.
  
  def self.create_integrity_check(text,universal_rules_md5, version_key)

    secret = universal_rules_md5 + version_key 

    if RUBY_SHA256_AVAILABLE
      hmac = OpenSSL::HMAC.new(secret, OpenSSL::Digest::SHA256.new)
      hmac.update(text)
      mac = hmac.to_s
    else # Java
      algorithm = "HmacSHA256"
      key_spec = javax.crypto.spec.SecretKeySpec.new(java.lang.String.new(secret).get_bytes, algorithm)
      hmac = javax.crypto.Mac.get_instance(algorithm)
      hmac.init(key_spec)
      raw_mac = hmac.do_final(java.lang.String.new(text).get_bytes)
      mac = hexify(raw_mac)
    end

    #printf("DEBUG - universal_rules_md5: #{universal_rules_md5}")
    #printf("DEBUG - version_key: #{version_key}")
    #printf("DEBUG - integrity_text size: #{text.size}\n")
    #printf("DEBUG - mac before adding check digits:\n#{mac}, #{mac.size}\n")

    result = add_check_digits(mac)

    #printf("DEBUG results: #{result}, #{result.size}\n")

    return result
  end

  # turn a raw array of bytes into a hex string
  def self.hexify(bytes)
    sb = java.lang.StringBuffer.new
    bytes.each do |it|
      sb.append(java.lang.Integer.to_hex_string(0x00ff & it).rjust(2, "0"))
    end
    sb.to_string
  end

end
