module ManageIQ::Providers
  module Hawkular
    class Inventory::Parser::MiddlewareManager < ManagerRefresh::Inventory::Parser
      include ::Hawkular::ClientUtils

      def initialize
        super
        @data_index = {}
      end

      def parse
        # the order of the method calls is important here, because they make use of @data_index
        fetch_middleware_servers
        fetch_domains_with_servers
        fetch_server_entities
        fetch_availability
      end

      def fetch_middleware_servers
        collector.feeds.each do |feed|
          collector.eaps(feed).each do |eap|
            server = persister.middleware_servers.find_or_build(eap.path)
            parse_middleware_server(eap, server)

            # if immutable or in container flag is not set, check also the agent resource
            if server.properties['Immutable'].nil? || server.properties['In Container'].nil?
              agent_resource_id = 'Local%20JMX~org.hawkular:type%3dhawkular-javaagent'
              feed_id = ::Hawkular::Inventory::CanonicalPath.parse(eap.path).feed_id
              agent_resource_path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id      => feed_id,
                                                                             :resource_ids => [agent_resource_id])
              agent_config = collector.config_data_for_resource(agent_resource_path.to_s)
              ['Immutable', 'In Container'].each do |feature|
                if agent_config.try(:[], 'value').try(:[], feature) == 'true'
                  server.properties[feature] = 'true'
                end
              end
            end

            if server.properties['In Container'] == 'true'
              container_id = collector.container_id(eap.feed)
              if container_id
                backing_ref = 'docker://' + container_id
                container = Container.find_by(:backing_ref => backing_ref)
                set_lives_on(server, container) if container
              end
            else
              associate_with_vm(server, eap.feed)
            end
          end
        end
      end

      def set_lives_on(server, lives_on)
        server.lives_on_id = lives_on.id
        server.lives_on_type = lives_on.type
      end

      def fetch_domains_with_servers
        collector.feeds.each do |feed|
          collector.domains(feed).each do |domain|
            parsed_domain = persister.middleware_domains.find_or_build(domain.path)
            parse_middleware_domain(feed, domain, parsed_domain)

            # add the server groups to the domain
            fetch_server_groups(feed, parsed_domain)

            # now it's safe to fetch the domain servers (it assumes the server groups to be already fetched)
            fetch_domain_servers(feed)
          end
        end
      end

      def fetch_server_groups(feed, parsed_domain)
        collector.server_groups(feed).map do |group|
          parsed_group = persister.middleware_server_groups.find_or_build(group.path)
          parse_middleware_server_group(group, parsed_group)

          # TODO: remove this index. Two options for this: 1) try to find or build the ems_ref
          # of the server group. 2) add `find_by` methods to InventoryCollection class. Once this
          # is removed, the order in #parse method will no longer be needed. For now, at least
          # domains, sever groups and domain servers must be collected in order.
          @data_index.store_path(:middleware_server_groups, :by_name, parsed_group[:name], parsed_group)

          parsed_group.middleware_domain = persister.middleware_domains.lazy_find(parsed_domain[:ems_ref])
        end
      end

      def fetch_domain_servers(feed)
        collector.domain_servers(feed).each do |domain_server|
          server_name = parse_domain_server_name(domain_server.id)

          server = persister.middleware_servers.find_or_build(domain_server.path)
          parse_middleware_server(domain_server, server, true, server_name)

          associate_with_vm(server, feed)

          # Add the association to server group. The information about what server is in which server group is under
          # the server-config resource's configuration
          config_path = domain_server.path.to_s.sub(/%2Fserver%3D/, '%2Fserver-config%3D')
          config = collector.config_data_for_resource(config_path)
          server_group_name = config['value']['Server Group']
          server_group = @data_index.fetch_path(:middleware_server_groups, :by_name, server_group_name)
          server.middleware_server_group = persister.middleware_server_groups.lazy_find(server_group[:ems_ref])
        end
      end

      def alternate_machine_id(machine_id)
        return if machine_id.nil?
        # See the BZ #1294461 [1] for a more complete background.
        # Here, we'll try to adjust the machine ID to the format from that bug. We expect to get a string like
        # this: 2f68d133a4bc4c4bb19ecb47d344746c . For such string, we should return
        # this: 33d1682f-bca4-4b4c-b19e-cb47d344746c .The actual BIOS UUID is probably returned in upcase, but other
        # providers store it in downcase, so, we let the upcase/downcase logic to other methods with more
        # business knowledge.
        # 1 - https://bugzilla.redhat.com/show_bug.cgi?id=1294461
        alternate = []
        alternate << swap_part(machine_id[0, 8])
        alternate << swap_part(machine_id[8, 4])
        alternate << swap_part(machine_id[12, 4])
        alternate << machine_id[16, 4]
        alternate << machine_id[20, 12]
        alternate.join('-')
      end

      def swap_part(part)
        # here, we receive parts of an UUID, split into an array with 2 chars each element, and reverse the invidual
        # elements, joining and reversing the final outcome
        # for instance:
        # 2f68d133 -> ["2f", "68", "d1", "33"] -> ["f2", "86", "1d", "33"] -> f2861d33 -> 33d1682f
        part.scan(/../).collect(&:reverse).join.reverse
      end

      def find_host_by_bios_uuid(machine_id)
        return if machine_id.nil?
        identity_system = machine_id.downcase

        if identity_system
          Vm.find_by(:uid_ems => identity_system,
                     :type    => uuid_provider_types)
        end
      end

      def uuid_provider_types
        # after the PoC, we might want to test/support these extra providers:
        # ManageIQ::Providers::Openstack::CloudManager::Vm
        # ManageIQ::Providers::Vmware::InfraManager::Vm
        'ManageIQ::Providers::Redhat::InfraManager::Vm'
      end

      def fetch_server_entities
        persister.middleware_servers.each do |eap|
          collector.child_resources(eap.ems_ref, true).map do |child|
            next unless child.type_path.end_with?('Deployment', 'Datasource', 'JMS%20Topic', 'JMS%20Queue')
            server = persister.middleware_servers.find(eap.ems_ref)
            process_server_entity(server, child)
          end
        end
      end

      def fetch_availability
        feeds_of_interest = persister.middleware_servers.to_a.map(&:feed).uniq
        fetch_server_availabilities(feeds_of_interest)
        fetch_deployment_availabilities(feeds_of_interest)
        fetch_domain_availabilities(feeds_of_interest)
      end

      def fetch_deployment_availabilities(feeds)
        collection = persister.middleware_deployments
        fetch_availabilities_for(feeds, collection, collection.model_class::AVAIL_TYPE_ID) do |deployment, availability|
          deployment.status = process_deployment_availability(availability.try(:[], 'data').try(:first))
        end
      end

      def fetch_server_availabilities(feeds)
        collection = persister.middleware_servers
        fetch_availabilities_for(feeds, collection, collection.model_class::AVAIL_TYPE_ID) do |server, availability|
          props = server.properties

          props['Availability'], props['Calculated Server State'] =
            process_server_availability(props['Server State'], availability.try(:[], 'data').try(:first))
        end
      end

      def fetch_domain_availabilities(feeds)
        collection = persister.middleware_domains
        fetch_availabilities_for(feeds, collection, collection.model_class::AVAIL_TYPE_ID) do |domain, availability|
          domain.properties['Availability'] =
            process_domain_availability(availability.try(:[], 'data').try(:first))
        end
      end

      def fetch_availabilities_for(feeds, collection, metric_type_id)
        resources_by_metric_id = {}
        metric_id_by_resource_path = {}

        feeds.each do |feed|
          status_metrics = collector.metrics_for_metric_type(feed, metric_type_id)
          status_metrics.each do |status_metric|
            status_metric_path = ::Hawkular::Inventory::CanonicalPath.parse(status_metric.path)
            # By dropping metric_id from the canonical path we end up with the resource path
            resource_path = ::Hawkular::Inventory::CanonicalPath.new(
              :tenant_id    => status_metric_path.tenant_id,
              :feed_id      => status_metric_path.feed_id,
              :resource_ids => status_metric_path.resource_ids
            )
            metric_id_by_resource_path[URI.decode(resource_path.to_s)] = status_metric.hawkular_metric_id
          end
        end

        collection.each do |item|
          yield item, nil

          path = URI.decode(item.try(:resource_path_for_metrics) ||
            item.try(:model_class).try(:resource_path_for_metrics, item) ||
            item.try(:ems_ref) ||
            item.manager_uuid)
          next unless metric_id_by_resource_path.key? path
          metric_id = metric_id_by_resource_path[path]
          resources_by_metric_id[metric_id] = [] unless resources_by_metric_id.key? metric_id
          resources_by_metric_id[metric_id] << item
        end

        unless resources_by_metric_id.empty?
          availabilities = collector.raw_availability_data(resources_by_metric_id.keys,
                                                           :limit => 1, :order => 'DESC')
          availabilities.each do |availability|
            resources_by_metric_id[availability['id']].each do |resource|
              yield resource, availability
            end
          end
        end
      end

      def process_entity_with_config(server, entity, inventory_object, continuation)
        entity_id = hawk_escape_id entity.id
        server_path = ::Hawkular::Inventory::CanonicalPath.parse(server[:ems_ref])
        resource_ids = server_path.resource_ids << entity_id
        resource_path = ::Hawkular::Inventory::CanonicalPath.new(:feed_id      => server_path.feed_id,
                                                                 :resource_ids => resource_ids)
        config = collector.config_data_for_resource(resource_path.to_s)
        send(continuation, entity, inventory_object, config)
      end

      def process_server_entity(server, entity)
        if entity.type_path.end_with?('Deployment')
          inventory_object = persister.middleware_deployments.find_or_build(entity.path)
          parse_deployment(entity, inventory_object)
        elsif entity.type_path.end_with?('Datasource')
          inventory_object = persister.middleware_datasources.find_or_build(entity.path)
          process_entity_with_config(server, entity, inventory_object, :parse_datasource)
        else
          inventory_object = persister.middleware_messagings.find_or_build(entity.path)
          process_entity_with_config(server, entity, inventory_object, :parse_messaging)
        end

        inventory_object.middleware_server = persister.middleware_servers.lazy_find(server.ems_ref)
        inventory_object.middleware_server_group = server.middleware_server_group if inventory_object.respond_to?(:middleware_server_group=)
      end

      def process_server_availability(server_state, availability = nil)
        avail = availability.try(:[], 'value') || 'unknown'
        [avail, avail == 'up' ? server_state : avail]
      end

      def process_deployment_availability(availability = nil)
        process_availability(availability, 'up' => 'Enabled', 'down' => 'Disabled')
      end

      def process_domain_availability(availability = nil)
        process_availability(availability, 'up' => 'Running', 'down' => 'Stopped')
      end

      def process_availability(availability, translation = {})
        translation.fetch(availability.try(:[], 'value').try(:downcase), 'Unknown')
      end

      def parse_deployment(deployment, inventory_object)
        parse_base_item(deployment, inventory_object)
        inventory_object.name = parse_deployment_name(deployment.id)
      end

      def parse_messaging(messaging, inventory_object, config)
        parse_base_item(messaging, inventory_object)
        inventory_object.name = messaging.name

        type_path = ::Hawkular::Inventory::CanonicalPath.parse(messaging.type_path)
        inventory_object.messaging_type = URI.decode(type_path.resource_type_id)

        if !config.empty? && !config['value'].empty? && config['value'].respond_to?(:except)
          inventory_object.properties = config['value'].except('Username', 'Password')
        end
      end

      def parse_datasource(datasource, inventory_object, config)
        parse_base_item(datasource, inventory_object)
        inventory_object.name = datasource.name

        if !config.empty? && !config['value'].empty? && config['value'].respond_to?(:except)
          inventory_object.properties = config['value'].except('Username', 'Password')
        end
      end

      def parse_middleware_domain(feed, domain, inventory_object)
        parse_base_item(domain, inventory_object)
        inventory_object.name = parse_domain_name(feed)
        inventory_object.type_path = domain.type_path
      end

      def parse_middleware_server_group(group, inventory_object)
        parse_base_item(group, inventory_object)
        inventory_object.assign_attributes(
          :name      => parse_server_group_name(group.name),
          :type_path => group.type_path,
          :profile   => group.properties['Profile']
        )
      end

      def parse_middleware_server(eap, inventory_object, domain = false, name = nil)
        parse_base_item(eap, inventory_object)

        not_started = domain && eap.properties['Server State'] == 'STOPPED'

        hostname, product = ['Hostname', 'Product Name'].map do |x|
          not_started && eap.properties[x].nil? ? _('not yet available') : eap.properties[x]
        end

        inventory_object.assign_attributes(
          :name      => name || parse_standalone_server_name(eap.id),
          :type_path => eap.type_path,
          :hostname  => hostname,
          :product   => product
        )
      end

      def associate_with_vm(server, feed)
        # Add the association to vm instance if there is any
        machine_id = collector.machine_id(feed)
        host_instance = find_host_by_bios_uuid(machine_id) ||
                        find_host_by_bios_uuid(alternate_machine_id(machine_id))
        set_lives_on(server, host_instance) if host_instance
      end

      private

      def parse_base_item(item, inventory_object)
        inventory_object.ems_ref = item.path
        inventory_object.nativeid = item.id

        [:properties, :feed].each do |field|
          inventory_object[field] = item.send(field) if item.respond_to?(field)
        end
      end

      def parse_deployment_name(name)
        name.sub(/^.*deployment=/, '')
      end

      def parse_server_group_name(name)
        name.sub(/^Domain Server Group \[/, '').chomp(']')
      end

      def parse_domain_server_name(name)
        name.sub(%r{^.*\/server=}, '')
      end

      def parse_domain_name(name)
        name.sub(/^[^\.]+\./, '')
      end

      def parse_standalone_server_name(name)
        name.sub(/~~$/, '').sub(/^.*?~/, '')
      end
    end
  end
end
