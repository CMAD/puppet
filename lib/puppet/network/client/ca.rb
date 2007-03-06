require 'puppet/network/client'

# Request a certificate from the remote system.
class Puppet::Network::Client::CA < Puppet::Network::Client
    class InvalidCertificate < Puppet::Error; end

    def initialize(options = {})
        options = symbolize_options(options)
        unless options.include?(:Server) or options.include?(:CA)
            options[:Server] = Puppet[:ca_server]
            options[:Port] = Puppet[:ca_port]
        end
        super(options)
    end

    # This client is really only able to request certificates for the
    # current host.  It uses the Puppet.config settings to figure everything out.
    def request_cert
        Puppet.config.use(:puppet, :certificates)

        if cert = read_cert
            return cert
        end

        begin
            cert, cacert = @driver.getcert(csr.to_pem)
        rescue => detail
            if Puppet[:trace]
                puts detail.backtrace
            end
            raise Puppet::Error.new("Certificate retrieval failed: %s" % detail)
        end

        if cert.nil? or cert == ""
            return nil
        end
        Puppet.config.write(:hostcert) do |f| f.print cert end
        Puppet.config.write(:localcacert) do |f| f.print cacert end

        begin
            @cert = OpenSSL::X509::Certificate.new(cert)
            @cacert = OpenSSL::X509::Certificate.new(cacert)
        rescue => detail
            raise InvalidCertificate.new(
                "Invalid certificate: %s" % detail
            )
        end

        unless @cert.check_private_key(key)
            raise InvalidCertificate, "Certificate does not match private key"
        end
        return @cert
    end
end

# $Id$
