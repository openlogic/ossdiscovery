Gem::Specification.new do |s|
  s.name = %q{jruby-openssl}
  s.version = "0.1.1"

  s.specification_version = 1 if s.respond_to? :specification_version=

  s.required_rubygems_version = nil if s.respond_to? :required_rubygems_version=
  s.authors = ["Ola Bini and JRuby contributors"]
  s.cert_chain = nil
  s.date = %q{2008-01-06}
  s.description = %q{JRuby-OpenSSL is an add-on gem for JRuby that emulates the Ruby OpenSSL native library.}
  s.email = %q{ola.bini@gmail.com}
  s.extra_rdoc_files = ["History.txt", "README.txt", "License.txt"]
  s.files = ["History.txt", "README.txt", "License.txt", "lib/jopenssl.jar", "lib/bcmail-jdk14-135.jar", "lib/bcprov-jdk14-135.jar", "lib/jopenssl", "lib/jopenssl/version.rb", "lib/openssl", "lib/openssl/bn.rb", "lib/openssl/buffering.rb", "lib/openssl/cipher.rb", "lib/openssl/digest.rb", "lib/openssl/dummy.rb", "lib/openssl/dummyssl.rb", "lib/openssl/ssl.rb", "lib/openssl/x509.rb", "lib/openssl.rb", "test/openssl", "test/openssl/ssl_server.rb", "test/openssl/test_asn1.rb", "test/openssl/test_cipher.rb", "test/openssl/test_digest.rb", "test/openssl/test_hmac.rb", "test/openssl/test_ns_spki.rb", "test/openssl/test_pair.rb", "test/openssl/test_pkey_rsa.rb", "test/openssl/test_ssl.rb", "test/openssl/test_x509cert.rb", "test/openssl/test_x509crl.rb", "test/openssl/test_x509ext.rb", "test/openssl/test_x509name.rb", "test/openssl/test_x509req.rb", "test/openssl/test_x509store.rb", "test/openssl/utils.rb", "test/test_openssl.rb", "test/ut_eof.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://jruby-extras.rubyforge.org/jopenssl}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new("> 0.0.0")
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.0.1}
  s.summary = %q{OpenSSL add-on for JRuby}
  s.test_files = ["test/test_openssl.rb"]
end
