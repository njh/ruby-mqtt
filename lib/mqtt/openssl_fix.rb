# frozen_string_literal: true

# This is a monkey patch to work around a missing method in OpenSSL.  Older
# versions of OpenSSL were missing the `getbyte` method (regular sockets have
# a getbyte method but OpenSSL sockets didn't).  We added `getbyte` to OpenSSL
# here: https://github.com/ruby/openssl/pull/438
#
# This patch is just to backport the `getbyte` method until folks are able to
# upgrade OpenSSL packages
unless OpenSSL::SSL::SSLSocket.method_defined?(:getbyte)
  class OpenSSL::SSL::SSLSocket
    def getbyte
      byte = read(1)
      byte && unpack_byte(byte)
    end

    private

    if ''.respond_to?(:unpack1)
      def unpack_byte(str)
        str.unpack1('C')
      end
    else
      def unpack_byte(str)
        str.unpack('C').first
      end
    end
  end
end
