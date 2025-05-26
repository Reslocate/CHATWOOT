require 'net/imap'

# Monkey patch for newer Net::IMAP versions
module Net
  class IMAP
    class << self
      alias_method :original_new, :new
      
      def new(host, **options)
        # Remove any SSL verification for older Ruby compatibility
        if options[:ssl] == true
          # For newer Net::IMAP, we need to modify the ssl options differently
          options[:ssl] = { verify_mode: OpenSSL::SSL::VERIFY_NONE }
        end
        
        original_new(host, **options)
      end
    end
  end
end

puts "Updated IMAP SSL patch loaded!"












