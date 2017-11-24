
          { 'tenantId'    => 'hawkular',
            'id'          => '1',
            'name'        => 'alert_profile',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :GROUP,
            'eventType'   => :EVENT,
            'firingMatch' => :ANY,
            'severity'    => 'MEDIUM',
            'context'     => {
              'dataId.hm.type'   => 'gauge',
              'dataId.hm.prefix' => 'hm_g_',
              'miq.alert_profiles' => '39' # MiqAlertSet#id
            },
            'tags'        => {
              'miq.event_type'    => 'hawkular_alert',
              'miq.resource_type' => 'Middleware Server'
            }
          },
          { 'tenantId'    => 'hawkular',
            'id'          => 'MiQ-region-7b5e3af1-ems-0f8c05f7-a96d-42af-bbac-3ae27a5516d2-alert-67-159',
            'name'        => 'alert_profile',
            'description' => 'alert_profile',
            'enabled'     => true,
            'type'        => :MEMBER,
            'eventType'   => :EVENT,
            'firingMatch' => :ANY,
            'autoResolveMatch' => 'ALL',
            'memberOf'    => 'MiQ-region-7b5e3af1-ems-0f8c05f7-a96d-42af-bbac-3ae27a5516d2-alert-67',
            'severity'    => 'MEDIUM',
            'context'     => {
              'dataId.hm.type'   => 'gauge',
              'dataId.hm.prefix' => 'hm_g_',
              'miq.alert_profiles' => "39",
              'resource_path'      => "/t;hawkular/f;d22af190e985/r;Local%20DMR~~" # server.ems_ref
            },
            'tags'        => {
              'miq.event_type'    => 'hawkular_alert',
              'miq.resource_type' => 'Middleware Server'
            },
            'dataIdMap' => {
              'WildFly Memory Metrics~Heap Max' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Max",
              'WildFly Memory Metrics~Heap Used' => "hm_g_MI~R~[d22af190e985/Local DMR~~]~MT~WildFly Memory Metrics~Heap Used"
            }
          }
