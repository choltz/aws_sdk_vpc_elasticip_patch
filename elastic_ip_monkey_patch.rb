# Public: Monkey patch to aws-sdk verion 1.3.7 to support elastic ip assignment
# to VPC ec2 instances.
module AWS
  class EC2

    class ElasticIpCollection < Collection
      def each &block
        response = filtered_request(:describe_addresses)
        response.addresses_set.each do |address|

          options = {}
          options[:config] = config
          options[:instance_id] = address.instance_id

          # Patch for aws-sdk 1.3.7: if the address has an allocaton id, make sure it gets passed into
          # the elastic ip object
          if address.respond_to?(:allocation_id)
            options[:allocation_id] = address.allocation_id
          end

          elastic_ip = ElasticIp.new(address.public_ip, options)

          yield(elastic_ip)
        end
      end
    end

    class ElasticIp < Resource
      # Patch for aws-sdk 1.3.7: add an attr accessor for the elastic ip
      # allocation id
      attr_accessor :allocation_id

      def initialize public_ip, options = {}
        options = { :allocation_id => nil }.update(options)
        @public_ip = public_ip

        # Patch for aws-sdk 1.3.7: save the allocation id to a class variable
        @allocation_id = options[:allocation_id]
        super
      end
    end

    class Instance < Resource
      def associate_elastic_ip elastic_ip
        # Patch for aws-sdk 1.3.7: If the instance is associated with a VPC
        # then pass the allocation id to the associate_address call rather than
        # the ip address
        if self.vpc.nil?
          client.associate_address(
            :public_ip => elastic_ip.to_s,
            :instance_id => self.id
            )
        else
          client.associate_address(
            :public_ip => "",
            :instance_id => self.id,
            :allocation_id => elastic_ip.allocation_id.to_s
            )
        end
        nil
      end
    end

  end
end
