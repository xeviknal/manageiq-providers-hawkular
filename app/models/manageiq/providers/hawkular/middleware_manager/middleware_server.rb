module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareServer < MiddlewareServer
    include ManageIQ::Providers::Hawkular::Common::Alert::Sync

    AVAIL_TYPE_ID = 'Server%20Availability~Server%20Availability'.freeze

    has_many :middleware_diagnostic_reports, :dependent => :destroy

    def feed
      CGI.unescape(super)
    end

    def immutable?
      properties['Immutable'] == 'true'
    end

    def enqueue_diagnostic_report(requesting_user:)
      middleware_diagnostic_reports.create!(
        :requesting_user => requesting_user
      )
    end

    def self.supported_models
      @supported_models ||= ['middleware_server']
    end
  end
end
