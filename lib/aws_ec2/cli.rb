module AwsEc2
  class CLI < Command
    class_option :verbose, type: :boolean
    class_option :noop, type: :boolean

    desc "create NAME", "create ec2 instance"
    long_desc Help.text(:create)
    def create(name)
      Create.new(options.merge(name: name)).run
    end
  end
end
