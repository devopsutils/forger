class Forger::Create
  class Info
    include Forger::AwsServices

    attr_reader :params
    def initialize(options, params)
      @options = options
      @params = params
    end

    def ec2_params
      puts "Using the following parameters:"
      pretty_display(params)

      launch_template
    end

    def spot(instance_id)
      retries = 0
      begin
        resp = ec2.describe_instances(instance_ids: [instance_id])
      rescue Aws::EC2::Errors::InvalidInstanceIDNotFound
        retries += 1
        puts "Aws::EC2::Errors::InvalidInstanceIDNotFound error. Retry: #{retries}"
        sleep 2**retries
        if retries <= 3
          retry
        else
          puts "Unable to find lauched spot instance"
          return
        end
      end

      reservation = resp.reservations.first
      # Super edge case when reserverations not immediately found yet
      until reservation
        resp = ec2.describe_instances(instance_ids: [instance_id])
        reservation = resp.reservations.first
        seconds = 0.5
        puts "Reserveration not found. Sleeping for #{seconds} and will try again."
        sleep seconds
      end
      spot_id = reservation.instances.first.spot_instance_request_id
      return unless spot_id

      puts "Spot instance request id: #{spot_id}"
    end

    def launch_template
      launch_template = params[:launch_template]
      return unless launch_template

      resp = ec2.describe_launch_template_versions(
        launch_template_id: launch_template[:launch_template_id],
        launch_template_name: launch_template[:launch_template_name],
      )
      versions = resp.launch_template_versions
      launch_template_data = {} # combined launch_template_data
      versions.sort_by { |v| v[:version_number] }.each do |v|
        launch_template_data.merge!(v[:launch_template_data])
      end
      puts "launch template data (versions combined):"
      pretty_display(launch_template_data)
    rescue Aws::EC2::Errors::InvalidLaunchTemplateNameNotFoundException => e
      puts "ERROR: The specified launched template #{launch_template.inspect} was not found."
      puts "Please double check that it exists."
      exit
    end

    def cloudwatch(instance_id)
      return unless Forger.cloudwatch_enabled?(@options)

      region = cloudwatch_log_region
      stream = "#{instance_id}/var/log/cloud-init-output.log"
      url = "https://#{region}.console.aws.amazon.com/cloudwatch/home?region=#{region}#logEventViewer:group=forger;stream=#{stream}"
      cw_init_log = "cw tail -f forger #{stream}"
      puts "To view instance's cloudwatch logs visit:"
      puts "  #{url}"

      puts "  #{cw_init_log}" if show_cw
      if show_cw && @options[:auto_terminate]
        cw_terminate_log = "cw tail -f forger #{instance_id}/var/log/auto-terminate.log"
        puts "  #{cw_terminate_log}"
      end

      puts "Note: It takes at least a few minutes for the instance to launch and report logs."

      paste_command = show_cw ? cw_init_log : url
      add_to_clipboard(paste_command)
    end

    def cloudwatch_log_region
      # Highest precedence: FORGER_REGION env variable. Only really used here.
      # This is useful to be able to override when running tool in codebuild.
      # Codebuild can be running in different region then the region which the
      # instance is launched in.
      # Getting the region from the the profile and metadata doesnt work in
      # this case.
      if ENV['FORGER_REGION']
        return ENV['FORGER_REGION']
      end

      # Pretty high in precedence: AWS_PROFILE and ~/.aws/config and
      aws_found = system("type aws > /dev/null")
      if aws_found
        region = `aws configure get region`.strip
        return region
      end

      # Assumes instance same region as the calling ec2 instance.
      # It is possible for curl not to be installed.
      curl_found = system("type curl > /dev/null")
      if curl_found
        region = `curl --connect-timeout 3  -s 169.254.169.254/latest/meta-data/placement/availability-zone | sed s'/.$//'`
        return region unless region == ''
      end

      return 'us-east-1' # fallback default
    end

    def pretty_display(data)
      data = data.deep_stringify_keys

      if data["user_data"]
        message = "base64-encoded: cat #{Forger.build_root}/user-data.txt to view"
        data["user_data"] = message
      end

      puts YAML.dump(data)
    end

    def show_cw
      ENV['FORGER_CW'] || system("type cw > /dev/null 2>&1")
    end

    def add_to_clipboard(text)
      return unless RUBY_PLATFORM =~ /darwin/
      return unless system("type pbcopy > /dev/null")

      system(%[echo "#{text}" | pbcopy])
      copy_item = show_cw ? "cw command" : "CloudWatch Console Link"
      puts "Pro tip: The #{copy_item} has been added to your copy-and-paste clipboard."
    end
  end
end
