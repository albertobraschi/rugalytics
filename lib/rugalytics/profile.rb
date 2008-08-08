module Rugalytics
  class Profile < ::Google::Base

    class << self
      def find_all(account_id)
        doc = Hpricot::XML get("https://www.google.com:443/analytics/settings/home?scid=#{account_id}")
        (doc/'select[@id=profile] option').inject([]) do |profiles, option|
          profile_id = option['value'].to_i
          profiles << Profile.new(:account_id => account_id, :profile_id => profile_id, :name => option.inner_html) if profile_id > 0
          profiles
        end
      end

      def find(account_id_or_name, profile_id_or_name=nil)
        profile_id_or_name = account_id_or_name unless profile_id_or_name
        account = Account.find(account_id_or_name)
        account ? account.find_profile(profile_id_or_name) : nil
      end
    end

    attr_accessor :account_id, :name, :profile_id

    def initialize(attrs)
      raise ArgumentError, ":profile_id is required" unless attrs.has_key?(:profile_id)
      @account_id = attrs[:account_id]  if attrs.has_key?(:account_id)
      @name       = attrs[:name]        if attrs.has_key?(:name)
      @profile_id = attrs[:profile_id]  if attrs.has_key?(:profile_id)
    end

    def method_missing symbol, *args
      if name = symbol.to_s[/^(.+)_report$/, 1]
        options = args && args.size == 1 ? args[0] : {}
        create_report(name.camelize, options)
      else
        super
      end
    end

    def load_report(name, options={})
      if options=={}
        ActiveSupport::Deprecation.warn "Profile#load_report('#{name}') has been deprecated, use Profile##{name.tableize}_report instead"
      else
        ActiveSupport::Deprecation.warn "Profile#load_report('#{name}',options) has been deprecated, use Profile##{name.tableize}_report(options) instead"
      end
      create_report(name, options={})
    end

    def get_report_csv(options={})
      options = set_default_options(options)
      params = convert_options_to_uri_params(options)
      self.class.get("https://google.com/analytics/reporting/export", :query_hash => params)
    end

    def convert_options_to_uri_params(options)
      params = {
        :pdr  => "#{options[:from]}-#{options[:to]}",
        :rpt  => "#{options[:report]}Report",
        :cmp  => options[:compute],
        :fmt  => options[:format],
        :view => options[:view],
        :tab  => options[:tab],
        :trows=> options[:rows],
        :gdfmt=> options[:gdfmt],
        :id   => profile_id
      }
      params[:d1] = options[:url] if options[:url]
      puts params.inspect
      params
    end

    def a_week_ago
      Time.now.utc - 7.days
    end

    def today
      Time.now.utc
    end

    def set_default_options(options)
      options.reverse_merge!({
        :report  => 'Dashboard',
        :from    => a_week_ago,
        :to      => today,
        :tab     => 0,
        :format  => FORMAT_CSV,
        :rows    => 50,
        :compute => 'average',
        :gdfmt   => 'nth_day',
        :view    => 0
      })
      options[:from] = ensure_datetime_in_google_format(options[:from])
      options[:to]   = ensure_datetime_in_google_format(options[:to])
      options
    end

    # Extract Page Views from Content Drilldown Report URLs.
    # Use with :url => "/projects/68263/" to options hash
    #
    # def drilldown(options={})
      # content_drilldown_report(options).pageviews_total
    # end
    #
    # instead do
    # profile.content_drilldown_report(:url => '/projects/68263/').pageviews_total

    def pageviews(options={})
      pageviews_report(options).pageviews_total
    end

    def pageviews_by_day(options={})
      pageviews_report(options).pageviews_by_day
    end

    def visits(options={})
      visits_report(options).visits_total
    end

    def visits_by_day(options={})
      visits_report(options).visits_by_day
    end

    # takes a Date, Time or String
    def ensure_datetime_in_google_format(time)
      time = Date.parse(time) if time.is_a?(String)
      time.is_a?(Time) || time.is_a?(Date) ? time.strftime('%Y%m%d') : time
    end

    def to_s
      "#{name} (#{profile_id})"
    end

    private

      def create_report(name, options={})
        report = Rugalytics::Report.new get_report_csv(options.merge({:report=>name}))
        puts report.attribute_names
        report
      end
  end
end