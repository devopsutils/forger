require "base64"
require "erb"
require "active_support/all"

module AwsEc2
  module TemplateHelper
    autoload :PartialSupport, 'aws_ec2/template_helper/partial_support'
    include PartialSupport

    def user_data(name, base64=true)
      # allow user to specify the path also
      if File.exist?(name)
        name = File.basename(name) # normalize name, change path to name
      end
      name = File.basename(name, '.sh')
      path = "#{root}/app/user-data/#{name}.sh"
      result = erb_result(path)
      result = append_ami_creation(result)

      base64 ? Base64.encode64(result).strip : result
    end

    # provides access to config/* settings as variables
    #   AWS_EC2_ENV=development => config/development.yml
    #   AWS_EC2_ENV=production => config/production.yml
    def config
      AwsEc2.config
    end

    # pretty timestamp that is useful for ami ids.
    # the timestamp is generated once and cached.
    def timestamp
      @timestamp ||= Time.now.strftime("%Y-%m-%d-%H-%M-%S")
    end

  private
    def append_ami_creation(user_data)
      ami = @options[:ami]

      if ami
        # assuming that the user-data script is a bash script here for simplicity
        # TODO: add support for other types of scripts
        # might be able to do this by wrapping all scripts in cloud-init
        ami_creation_snippet = AwsEc2::Ami.new(ami).user_data_snippet
        user_data += ami_creation_snippet
      end
      user_data
    end

    # Load custom helper methods from the project repo
    def load_custom_helpers
      Dir.glob("#{AwsEc2.root}/app/helpers/**/*_helper.rb").each do |path|
        filename = path.sub(%r{.*/},'').sub('.rb','')
        module_name = filename.classify

        require path
        self.class.send :include, module_name.constantize
      end

    end

    def erb_result(path)
      load_custom_helpers
      template = IO.read(path)
      begin
        ERB.new(template, nil, "-").result(binding)
      rescue Exception => e
        puts e

        # how to know where ERB stopped? - https://www.ruby-forum.com/topic/182051
        # syntax errors have the (erb):xxx info in e.message
        # undefined variables have (erb):xxx info in e.backtrac
        error_info = e.message.split("\n").grep(/\(erb\)/)[0]
        error_info ||= e.backtrace.grep(/\(erb\)/)[0]
        raise unless error_info # unable to find the (erb):xxx: error line
        line = error_info.split(':')[1].to_i
        puts "Error evaluating ERB template on line #{line.to_s.colorize(:red)} of: #{path.sub(/^\.\//, '')}"

        template_lines = template.split("\n")
        context = 5 # lines of context
        top, bottom = [line-context-1, 0].max, line+context-1
        spacing = template_lines.size.to_s.size
        template_lines[top..bottom].each_with_index do |line_content, index|
          line_number = top+index+1
          if line_number == line
            printf("%#{spacing}d %s\n".colorize(:red), line_number, line_content)
          else
            printf("%#{spacing}d %s\n", line_number, line_content)
          end
        end
        exit 1 unless ENV['TEST']
      end
    end
  end
end
